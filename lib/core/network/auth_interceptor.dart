import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'session_expired_notifier.dart';
import 'token_refresher.dart';

/// Attaches the stored access token to every authenticated request and
/// transparently refreshes it on a 401 response.
///
/// Only the following endpoints work without a session and are skipped both
/// for header attachment and for the refresh-on-401 flow: `POST
/// /v1/auth/login`, `POST /v1/auth/refresh`, `POST /v1/users` (register) and
/// `GET /v1/users/dni/:dni` (DNI lookup). Every other `/v1/users/...` call
/// (e.g. `GET`/`PATCH /v1/users/:id`, used to read/save the current user's
/// emergency contacts) is authenticated like any other endpoint — the path
/// alone is not enough to tell them apart from the public ones, so the HTTP
/// method matters too.
///
/// The actual refresh call is delegated to [TokenRefresher] (shared with
/// `RealtimeServiceImpl`'s auth-rejected socket reconnect path), which uses
/// its own interceptor-free [Dio] so a refresh call can never trigger this
/// interceptor again (no loops). The retried original request goes back
/// through [_dioProvider]'s Dio instance so it keeps the app's normal
/// interceptor chain (e.g. logging).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio Function() dioProvider,
    required SecureStorage storage,
    required SessionExpiredNotifier sessionExpiredNotifier,
    required TokenRefresher tokenRefresher,
  })  : _dioProvider = dioProvider,
        _storage = storage,
        _sessionExpiredNotifier = sessionExpiredNotifier,
        _tokenRefresher = tokenRefresher;

  static const String retriedExtraKey = 'auth_interceptor_retried';

  final Dio Function() _dioProvider;
  final SecureStorage _storage;
  final SessionExpiredNotifier _sessionExpiredNotifier;
  final TokenRefresher _tokenRefresher;

  /// Exactly the public (session-less) endpoints. The method matters: e.g.
  /// `POST /v1/users` (register) is public, but `GET`/`PATCH /v1/users/:id`
  /// is not.
  static bool _isPublicPath(String method, String path) {
    switch (method.toUpperCase()) {
      case 'POST':
        return path == '/v1/auth/login' ||
            path == '/v1/auth/refresh' ||
            path == '/v1/users';
      case 'GET':
        return path == '/v1/users/dni' || path.startsWith('/v1/users/dni/');
      default:
        return false;
    }
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicPath(options.method, options.path) &&
        !options.headers.containsKey('Authorization')) {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final statusCode = err.response?.statusCode;

    if (statusCode != 401 || _isPublicPath(options.method, options.path)) {
      handler.next(err);
      return;
    }

    if (options.extra[retriedExtraKey] == true) {
      // The retried request failed again with 401: give up, no loops.
      await _handleSessionExpired();
      handler.next(err);
      return;
    }

    final newToken = await _refreshTokens();
    if (newToken == null) {
      // Refresh failed (or there was no refresh token); the session was
      // already cleared inside _refreshTokens.
      handler.next(err);
      return;
    }

    try {
      options.extra[retriedExtraKey] = true;
      options.headers['Authorization'] = 'Bearer $newToken';
      final response = await _dioProvider().fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      // If this was a 401 again, the recursive onError call above already
      // cleared the session and notified listeners.
      handler.next(retryError);
    }
  }

  Future<String?> _refreshTokens() => _tokenRefresher.refresh();

  Future<void> _handleSessionExpired() async {
    await _storage.clearSession();
    _sessionExpiredNotifier.notify();
  }
}
