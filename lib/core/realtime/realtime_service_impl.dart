import 'dart:async';

import '../network/account_disabled_notifier.dart';
import '../storage/secure_storage.dart';
import 'realtime_service.dart';
import 'socket_connection.dart';

/// Default (and only) implementation of [RealtimeService], built on a
/// [SocketConnection] seam so it can be unit-tested without a real socket.
///
/// Reconnection policy: the underlying [SocketConnection] has its own
/// automatic reconnection disabled ([IoSocketConnection] configures this),
/// so this class owns the entire retry policy. Every disconnect that wasn't
/// requested by the app (logout, session expiry, `disableUser`) gets
/// exactly one retry, using the token currently in [SecureStorage] — which
/// picks up a token refreshed by `AuthInterceptor` in the meantime, since
/// [connect] always re-reads it. The retry guard resets on the next
/// successful connection, so a later, unrelated disconnect still gets its
/// own single retry; it never loops.
class RealtimeServiceImpl implements RealtimeService {
  RealtimeServiceImpl({
    required SocketConnection socket,
    required SecureStorage storage,
    required AccountDisabledNotifier accountDisabledNotifier,
  })  : _socket = socket,
        _storage = storage,
        _accountDisabledNotifier = accountDisabledNotifier {
    _socket.onConnect(() {
      _hasRetriedAfterDisconnect = false;
    });
    _socket.onConnectError((_) {
      unawaited(_retryOnce());
    });
    _socket.onDisconnect((_) {
      unawaited(_retryOnce());
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

  final SocketConnection _socket;
  final SecureStorage _storage;
  final AccountDisabledNotifier _accountDisabledNotifier;
  final StreamController<Map<String, dynamic>> _updatedAlertsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Guards against a reconnect loop: at most one retry per disconnect,
  /// reset once a connection actually succeeds.
  bool _hasRetriedAfterDisconnect = false;

  /// Set for a disconnect the app itself requested (logout, session expiry,
  /// disableUser), so that disconnect never triggers a retry.
  bool _manualDisconnect = false;

  @override
  Stream<Map<String, dynamic>> get updatedAlerts =>
      _updatedAlertsController.stream;

  @override
  Future<void> connect() async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    _manualDisconnect = false;
    _socket.auth = {'token': token};
    _socket.connect();
  }

  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _socket.disconnect();
  }

  Future<void> _retryOnce() async {
    if (_manualDisconnect || _hasRetriedAfterDisconnect) {
      return;
    }
    _hasRetriedAfterDisconnect = true;
    await connect();
  }

  Future<void> _handleDisableUser(String message) async {
    _manualDisconnect = true;
    await _storage.clearSession();
    _socket.disconnect();
    _accountDisabledNotifier.notify(message);
  }

  void dispose() {
    _updatedAlertsController.close();
  }
}
