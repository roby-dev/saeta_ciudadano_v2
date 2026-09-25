import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String userId,
    required bool rememberMe,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyToken, value: token),
      _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
      _storage.write(key: AppConstants.keyUserId, value: userId),
      _storage.write(
          key: AppConstants.keyRememberMe, value: rememberMe.toString()),
    ]);
  }

  /// Persists a refreshed access token and refresh token pair without
  /// touching the stored userId or rememberMe flag.
  Future<void> updateTokens({
    required String token,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyToken, value: token),
      _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getToken() =>
      _storage.read(key: AppConstants.keyToken);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.keyRefreshToken);

  Future<String?> getUserId() =>
      _storage.read(key: AppConstants.keyUserId);

  Future<bool> isSessionSaved() async {
    final value = await _storage.read(key: AppConstants.keyRememberMe);
    return value == 'true';
  }

  /// Local-only preference (not synced to the backend): whether emergency
  /// contacts should be SMS'd (device composer) when an alert is sent.
  /// Defaults to false.
  Future<void> setSendSmsOnAlert(bool value) =>
      _storage.write(key: AppConstants.keySendSmsOnAlert, value: '$value');

  Future<bool> getSendSmsOnAlert() async {
    final value = await _storage.read(key: AppConstants.keySendSmsOnAlert);
    return value == 'true';
  }

  /// Clears the session and resets device-local, session-scoped
  /// preferences. This is the single choke point every end-of-session path
  /// goes through (manual logout, `AuthInterceptor`'s session-expired
  /// handling, and the realtime `disableUser` handler), so resetting
  /// `sendSmsOnAlert` here — rather than in each caller — covers all three.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyToken),
      _storage.delete(key: AppConstants.keyRefreshToken),
      _storage.delete(key: AppConstants.keyUserId),
      _storage.delete(key: AppConstants.keyRememberMe),
      setSendSmsOnAlert(false),
    ]);
  }
}
