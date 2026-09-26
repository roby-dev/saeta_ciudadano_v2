import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'core/network/account_disabled_notifier.dart';
import 'core/network/auth_interceptor.dart';
import 'core/network/http_client.dart';
import 'core/network/session_expired_notifier.dart';
import 'core/network/token_refresher.dart';
import 'core/realtime/io_socket_connection.dart';
import 'core/realtime/realtime_service.dart';
import 'core/realtime/realtime_service_impl.dart';
import 'core/realtime/socket_connection.dart';
import 'core/storage/secure_storage.dart';
import 'features/alerts/data/datasources/alerts_remote_datasource.dart';
import 'features/alerts/data/repositories/alerts_repository_impl.dart';
import 'features/alerts/domain/repositories/alerts_repository.dart';
import 'features/alerts/domain/usecases/get_user_alerts_usecase.dart';
import 'features/alerts/domain/usecases/send_alert_feedback_usecase.dart';
import 'features/alerts/presentation/providers/alerts_provider.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/get_current_user_usecase.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/emergency/data/datasources/emergency_remote_datasource.dart';
import 'features/emergency/data/repositories/emergency_repository_impl.dart';
import 'features/emergency/domain/repositories/emergency_repository.dart';
import 'features/emergency/domain/usecases/get_alert_types_usecase.dart';
import 'features/emergency/domain/usecases/send_alert_usecase.dart';
import 'features/emergency/presentation/providers/emergency_provider.dart';
import 'features/emergency_contacts/data/datasources/emergency_contacts_remote_datasource.dart';
import 'features/emergency_contacts/data/repositories/emergency_contacts_repository_impl.dart';
import 'features/emergency_contacts/data/services/native_device_contact_picker.dart';
import 'features/emergency_contacts/domain/repositories/emergency_contacts_repository.dart';
import 'features/emergency_contacts/domain/services/device_contact_picker.dart';
import 'features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import 'features/emergency_contacts/domain/services/sms_launcher.dart';
import 'features/emergency_contacts/domain/services/sms_message_builder.dart';
import 'features/emergency_contacts/domain/services/url_launcher_sms_launcher.dart';
import 'features/emergency_contacts/domain/usecases/get_emergency_contacts_usecase.dart';
import 'features/emergency_contacts/domain/usecases/save_emergency_contacts_usecase.dart';
import 'features/emergency_contacts/presentation/providers/emergency_contacts_provider.dart';
import 'features/profile/data/datasources/profile_remote_datasource.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/profile/domain/usecases/update_profile_usecase.dart';
import 'features/register/data/datasources/register_remote_datasource.dart';
import 'features/register/data/repositories/register_repository_impl.dart';
import 'features/register/domain/repositories/register_repository.dart';
import 'features/register/domain/usecases/lookup_dni_usecase.dart';
import 'features/register/domain/usecases/register_usecase.dart';
import 'features/register/presentation/bloc/register_bloc.dart';

final sl = GetIt.instance;

/// Instance name for the plain [Dio] used only by [AuthInterceptor] to call
/// the refresh endpoint. It has no interceptors of its own so a refresh
/// call can never trigger another refresh (no loops).
const String authDioInstanceName = 'authDio';

Future<void> setupServiceLocator() async {
  // Infrastructure
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<SecureStorage>(
    () => SecureStorage(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<SessionExpiredNotifier>(
    () => SessionExpiredNotifier(),
  );
  sl.registerLazySingleton<AccountDisabledNotifier>(
    () => AccountDisabledNotifier(),
  );
  sl.registerLazySingleton<Dio>(
    () => HttpClient.create(),
    instanceName: authDioInstanceName,
  );
  // Shared single-flight refresh, used by both AuthInterceptor (401 retries
  // on REST calls) and RealtimeService (auth-rejected socket reconnects).
  sl.registerLazySingleton<TokenRefresher>(
    () => TokenRefresher(
      authDio: sl<Dio>(instanceName: authDioInstanceName),
      storage: sl<SecureStorage>(),
      sessionExpiredNotifier: sl<SessionExpiredNotifier>(),
    ),
  );
  sl.registerLazySingleton<SocketConnection>(
    () => IoSocketConnection(),
  );
  sl.registerLazySingleton<RealtimeService>(
    () => RealtimeServiceImpl(
      socket: sl<SocketConnection>(),
      storage: sl<SecureStorage>(),
      accountDisabledNotifier: sl<AccountDisabledNotifier>(),
      tokenRefresher: sl<TokenRefresher>(),
    ),
  );
  sl.registerLazySingleton<Dio>(() {
    final dio = HttpClient.create();
    dio.interceptors.add(
      AuthInterceptor(
        dioProvider: () => sl<Dio>(),
        storage: sl<SecureStorage>(),
        sessionExpiredNotifier: sl<SessionExpiredNotifier>(),
        tokenRefresher: sl<TokenRefresher>(),
      ),
    );
    return dio;
  });

  // Auth — data
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>()),
  );

  // Auth — domain
  sl.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton<GetCurrentUserUseCase>(
    () => GetCurrentUserUseCase(sl<AuthRepository>()),
  );

  // Auth — presentation
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      storage: sl<SecureStorage>(),
    ),
  );

  // Register — data
  sl.registerLazySingleton<RegisterRemoteDataSource>(
    () => RegisterRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<RegisterRepository>(
    () => RegisterRepositoryImpl(
      sl<RegisterRemoteDataSource>(),
      sl<AuthRemoteDataSource>(),
    ),
  );

  // Register — domain
  sl.registerLazySingleton<LookupDniUseCase>(
    () => LookupDniUseCase(sl<RegisterRepository>()),
  );
  sl.registerLazySingleton<RegisterUseCase>(
    () => RegisterUseCase(sl<RegisterRepository>()),
  );

  // Register — presentation
  sl.registerFactory<RegisterBloc>(
    () => RegisterBloc(
      lookupDniUseCase: sl<LookupDniUseCase>(),
      registerUseCase: sl<RegisterUseCase>(),
      storage: sl<SecureStorage>(),
    ),
  );

  // Emergency — data
  sl.registerLazySingleton<EmergencyRemoteDataSource>(
    () => EmergencyRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<EmergencyRepository>(
    () => EmergencyRepositoryImpl(sl<EmergencyRemoteDataSource>()),
  );

  // Emergency — domain
  sl.registerLazySingleton<GetAlertTypesUseCase>(
    () => GetAlertTypesUseCase(sl<EmergencyRepository>()),
  );
  sl.registerLazySingleton<SendAlertUseCase>(
    () => SendAlertUseCase(sl<EmergencyRepository>()),
  );

  // Emergency — presentation (Provider)
  sl.registerFactory<EmergencyProvider>(
    () => EmergencyProvider(
      getAlertTypesUseCase: sl<GetAlertTypesUseCase>(),
      sendAlertUseCase: sl<SendAlertUseCase>(),
    ),
  );

  // Alerts — data
  sl.registerLazySingleton<AlertsRemoteDataSource>(
    () => AlertsRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<AlertsRepository>(
    () => AlertsRepositoryImpl(sl<AlertsRemoteDataSource>()),
  );

  // Alerts — domain
  sl.registerLazySingleton<GetUserAlertsUseCase>(
    () => GetUserAlertsUseCase(sl<AlertsRepository>()),
  );
  sl.registerLazySingleton<SendAlertFeedbackUseCase>(
    () => SendAlertFeedbackUseCase(sl<AlertsRepository>()),
  );

  // Alerts — presentation (Provider)
  sl.registerFactory<AlertsProvider>(
    () => AlertsProvider(
      getUserAlertsUseCase: sl<GetUserAlertsUseCase>(),
      sendAlertFeedbackUseCase: sl<SendAlertFeedbackUseCase>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );

  // Emergency contacts — data
  sl.registerLazySingleton<EmergencyContactsRemoteDataSource>(
    () => EmergencyContactsRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<EmergencyContactsRepository>(
    () => EmergencyContactsRepositoryImpl(sl<EmergencyContactsRemoteDataSource>()),
  );

  // Emergency contacts — domain
  sl.registerLazySingleton<GetEmergencyContactsUseCase>(
    () => GetEmergencyContactsUseCase(sl<EmergencyContactsRepository>()),
  );
  sl.registerLazySingleton<SaveEmergencyContactsUseCase>(
    () => SaveEmergencyContactsUseCase(sl<EmergencyContactsRepository>()),
  );
  sl.registerLazySingleton<DeviceContactPicker>(
    () => NativeDeviceContactPicker(),
  );
  sl.registerLazySingleton<SmsLauncher>(() => UrlLauncherSmsLauncher());
  sl.registerLazySingleton<PeruvianPhoneNormalizer>(
    () => const PeruvianPhoneNormalizer(),
  );
  sl.registerLazySingleton<SmsMessageBuilder>(
    () => const SmsMessageBuilder(),
  );

  // Emergency contacts — presentation (Provider)
  sl.registerFactory<EmergencyContactsProvider>(
    () => EmergencyContactsProvider(
      getContactsUseCase: sl<GetEmergencyContactsUseCase>(),
      saveContactsUseCase: sl<SaveEmergencyContactsUseCase>(),
      storage: sl<SecureStorage>(),
      contactPicker: sl<DeviceContactPicker>(),
      smsLauncher: sl<SmsLauncher>(),
      phoneNormalizer: sl<PeruvianPhoneNormalizer>(),
      messageBuilder: sl<SmsMessageBuilder>(),
      realtimeService: sl<RealtimeService>(),
    ),
  );

  // Profile — data
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
  );

  // Profile — domain
  sl.registerLazySingleton<UpdateProfileUseCase>(
    () => UpdateProfileUseCase(sl<ProfileRepository>()),
  );
  // ProfileEditProvider itself is constructed directly in
  // ProfileEditPage (needs the runtime currentUser + an onUpdated callback
  // into MainNavigationProvider, same convention as MainNavigationProvider
  // being constructed directly in MainPage rather than via a get_it factory).
}
