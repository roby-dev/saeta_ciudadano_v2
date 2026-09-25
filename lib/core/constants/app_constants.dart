class AppConstants {
  AppConstants._();

  // API — Saeta backend
  static const String baseUrlSaeta =
      'https://saeta-backend-v2-production.up.railway.app';

  // Timeouts (seconds)
  static const int connectTimeout = 10;
  static const int readTimeout = 30;
  static const int writeTimeout = 15;

  // Storage keys
  static const String keyToken = 'session_token';
  static const String keyRefreshToken = 'session_refresh_token';
  static const String keyUserId = 'session_user_id';
  static const String keyRememberMe = 'session_remember_me';
  static const String keySendSmsOnAlert = 'send_sms_on_alert';

  // User defaults
  static const String citizenRole = 'CIUDADANO';
  static const String defaultUserState = 'HABILITADO';

  // Alert states
  static const String alertStateResolved = 'Resuelta';
  static const String alertStateInProcess = 'En proceso';
  static const String alertStatePending = 'Pendiente';
  static const String alertStateCancelled = 'Cancelada';

  // Named routes
  static const String routeSplash = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeMain = '/main';
}
