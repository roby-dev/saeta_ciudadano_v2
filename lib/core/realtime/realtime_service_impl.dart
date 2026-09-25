import 'dart:async';
import 'dart:math';

import '../network/account_disabled_notifier.dart';
import '../network/token_refresher.dart';
import '../storage/secure_storage.dart';
import 'realtime_service.dart';
import 'socket_connection.dart';

/// Default (and only) implementation of [RealtimeService], built on a
/// [SocketConnection] seam so it can be unit-tested without a real socket.
///
/// Reconnection policy: the underlying [SocketConnection] has its own
/// automatic reconnection disabled ([IoSocketConnection] configures this),
/// so this class owns the entire retry policy, split by failure type:
///
/// - **Network-type failures** (`connect_error`, or a disconnect whose
///   reason isn't `'io server disconnect'` — covers `transport close` and
///   `ping timeout`): unlimited exponential-backoff retries (1s, 2s, 4s,
///   8s, 16s, capped at 30s, plus bounded jitter), reset to the first step
///   after the next successful connect. Every attempt re-reads the current
///   token from [SecureStorage] (via [connect]), so a token refreshed by
///   `AuthInterceptor` in the meantime is picked up automatically.
/// - **Auth-type failures**: a disconnect whose reason is exactly `'io
///   server disconnect'` — the backend's `RealtimeGateway.handleConnection`
///   rejects an unauthenticated/expired-token socket with
///   `client.disconnect(true)`, which the client observes as this exact
///   reason. This is distinct from `disableUser` (also server-initiated,
///   but explicitly signalled first and never retried — see below). On
///   this failure, [_tokenRefresher] is used exactly once to refresh the
///   access token, then exactly one reconnect is attempted with the new
///   token. A second consecutive auth rejection (the just-refreshed token
///   was rejected too) stops retrying entirely — no loop against a
///   permanently-invalid session. A failed refresh is already handled by
///   [TokenRefresher] itself (session cleared, `SessionExpiredNotifier`
///   notified), so this class does nothing further in that case either.
/// - **Explicit disconnects** (manual logout, session expiry, and
///   `disableUser`) cancel any pending backoff timer and never schedule a
///   retry.
///
/// Time is driven by plain [Timer]/`Future` APIs so `package:fake_async`
/// fully controls it in tests — no bespoke clock abstraction needed.
class RealtimeServiceImpl implements RealtimeService {
  RealtimeServiceImpl({
    required SocketConnection socket,
    required SecureStorage storage,
    required AccountDisabledNotifier accountDisabledNotifier,
    required TokenRefresher tokenRefresher,
    Duration Function(int attempt)? backoffForAttempt,
    int Function()? jitterMillis,
  })  : _socket = socket,
        _storage = storage,
        _accountDisabledNotifier = accountDisabledNotifier,
        _tokenRefresher = tokenRefresher,
        _backoffForAttempt = backoffForAttempt ?? _defaultBackoff,
        _jitterMillis = jitterMillis ?? _defaultJitter {
    _socket.onConnect(() {
      _connected = true;
      _retryAttempt = 0;
      _authReconnectAttempted = false;
      _cancelPendingRetry();
    });
    _socket.onConnectError((_) {
      _connected = false;
      _scheduleNetworkRetry();
    });
    _socket.onDisconnect((reason) {
      _connected = false;
      if (_explicitDisconnect) {
        return;
      }
      if (reason == _serverDisconnectReason) {
        unawaited(_handleAuthRejection());
      } else {
        _scheduleNetworkRetry();
      }
    });
    _socket.on('updatedAlert', (data) {
      if (data is Map) {
        _updatedAlertsController.add(Map<String, dynamic>.from(data));
      }
    });
    _socket.on('disableUser', (data) {
      final message = data is String && data.isNotEmpty
          ? data
          : 'Su cuenta ha sido deshabilitada';
      unawaited(_handleDisableUser(message));
    });
  }

  /// The exact disconnect reason the vendor client reports when the
  /// server calls `client.disconnect(true)` (both for an unauthenticated
  /// `handleConnection` rejection and for `disableUser`'s forced
  /// disconnect).
  static const String _serverDisconnectReason = 'io server disconnect';

  /// Backoff cap and jitter bound, per the task spec ("1s, 2s, 4s ...
  /// capped at 30s").
  static const int _backoffCapMs = 30000;
  static const int _jitterCapMs = 250;

  final SocketConnection _socket;
  final SecureStorage _storage;
  final AccountDisabledNotifier _accountDisabledNotifier;
  final TokenRefresher _tokenRefresher;
  final Duration Function(int attempt) _backoffForAttempt;
  final int Function() _jitterMillis;
  final StreamController<Map<String, dynamic>> _updatedAlertsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Whether the socket is currently believed to be connected (updated by
  /// [SocketConnection.onConnect]/`onDisconnect`/`onConnectError`).
  bool _connected = false;

  /// Set for a disconnect the app itself requested (logout, session
  /// expiry, `disableUser`) or while there's no session, so it never
  /// triggers a retry. Cleared at the start of every [connect] call.
  bool _explicitDisconnect = false;

  /// Consecutive network-type failures since the last successful connect,
  /// used to compute the next backoff delay. Reset on every successful
  /// connect.
  int _retryAttempt = 0;

  /// Guards the auth-rejection path to exactly one refresh-then-reconnect
  /// cycle per failure streak, reset only by a real successful connect.
  bool _authReconnectAttempted = false;

  Timer? _retryTimer;

  @override
  Stream<Map<String, dynamic>> get updatedAlerts =>
      _updatedAlertsController.stream;

  @override
  Future<void> connect() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    _explicitDisconnect = false;
    _socket.auth = {'token': token};
    _socket.connect();
  }

  @override
  Future<void> disconnect() async {
    _explicitDisconnect = true;
    _cancelPendingRetry();
    _socket.disconnect();
  }

  @override
  Future<void> reconnectOnResume() async {
    if (_explicitDisconnect || _connected) {
      return;
    }
    _cancelPendingRetry();
    _retryAttempt = 0;
    await connect();
  }

  void _scheduleNetworkRetry() {
    if (_explicitDisconnect) {
      return;
    }
    _cancelPendingRetry();
    final delay =
        _backoffForAttempt(_retryAttempt) + Duration(milliseconds: _jitterMillis());
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      unawaited(connect());
    });
  }

  Future<void> _handleAuthRejection() async {
    if (_authReconnectAttempted) {
      // Already tried refresh-once-then-reconnect-once for this failure
      // streak and got rejected again: stop retrying entirely, no loop.
      return;
    }
    _authReconnectAttempted = true;
    final newToken = await _tokenRefresher.refresh();
    if (newToken == null) {
      // Refresh failed (or there was no refresh token): TokenRefresher
      // already cleared the session and notified SessionExpiredNotifier.
      // Stop retrying.
      return;
    }
    await connect();
  }

  Future<void> _handleDisableUser(String message) async {
    _explicitDisconnect = true;
    _cancelPendingRetry();
    await _storage.clearSession();
    _socket.disconnect();
    _accountDisabledNotifier.notify(message);
  }

  void _cancelPendingRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  static Duration _defaultBackoff(int attempt) {
    final exponent = attempt.clamp(0, 30); // clamp before the shift below
    final baseMs = exponent >= 5 ? _backoffCapMs : 1000 * (1 << exponent);
    return Duration(milliseconds: min(baseMs, _backoffCapMs));
  }

  static int _defaultJitter() => Random().nextInt(_jitterCapMs);

  void dispose() {
    _cancelPendingRetry();
    _updatedAlertsController.close();
  }
}
