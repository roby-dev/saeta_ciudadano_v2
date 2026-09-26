import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'session_expired_notifier.dart';

/// Single-flight access-token refresh, shared by [AuthInterceptor] (401
/// retries on any authenticated REST call) and `RealtimeServiceImpl` (the
/// socket's auth-rejected reconnect path).
///
/// Both callers need the same guarantees: concurrent callers await the same
/// in-flight refresh instead of issuing one call each, and a refresh that
/// cannot be completed (no stored refresh token, or the refresh call itself
/// fails) clears the session and notifies [SessionExpiredNotifier] exactly
/// once rather than leaving the caller to figure that out itself.
class TokenRefresher {
  TokenRefresher({
    required Dio authDio,
    required SecureStorage storage,
    required SessionExpiredNotifier sessionExpiredNotifier,
  })  : _authDio = authDio,
        _storage = storage,
        _sessionExpiredNotifier = sessionExpiredNotifier;

  final Dio _authDio;
  final SecureStorage _storage;
  final SessionExpiredNotifier _sessionExpiredNotifier;

  /// Shared in-flight refresh future, so concurrent callers trigger exactly
  /// one call to the refresh endpoint instead of one each.
  Future<String?>? _refreshing;

  /// Refreshes the access token. Returns the new access token on success.
  /// Returns `null` when the refresh could not be completed — in which
  /// case the session has already been cleared and
  /// [SessionExpiredNotifier] has already been notified, so the caller
  /// only needs to stop (no further session-expired handling required).
  Future<String?> refresh() {
    final inFlight = _refreshing;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _performRefresh();
    _refreshing = future;
    future.whenComplete(() => _refreshing = null);
    return future;
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _handleSessionExpired();
      return null;
    }

    try {
      final response = await _authDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data ?? <String, dynamic>{};
      final newAccessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _handleSessionExpired();
        return null;
      }

      await _storage.updateTokens(
        token: newAccessToken,
        refreshToken:
            (newRefreshToken != null && newRefreshToken.isNotEmpty)
                ? newRefreshToken
                : refreshToken,
      );
      return newAccessToken;
    } on DioException {
      await _handleSessionExpired();
      return null;
    }
  }

  Future<void> _handleSessionExpired() async {
    await _storage.clearSession();
    _sessionExpiredNotifier.notify();
  }
}
