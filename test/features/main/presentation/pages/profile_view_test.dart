import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/device_contact_picker.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_launcher.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_message_builder.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/usecases/get_emergency_contacts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/usecases/save_emergency_contacts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/presentation/providers/emergency_contacts_provider.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/pages/profile_view.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/providers/main_navigation_provider.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_file_validator.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_image_picker.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:saeta_ciudadano_v2/service_locator.dart';
import 'package:dartz/dartz.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

class MockRealtimeService extends Mock implements RealtimeService {}

class MockGetEmergencyContactsUseCase extends Mock
    implements GetEmergencyContactsUseCase {}

class MockSaveEmergencyContactsUseCase extends Mock
    implements SaveEmergencyContactsUseCase {}

class MockDeviceContactPicker extends Mock implements DeviceContactPicker {}

class MockSmsLauncher extends Mock implements SmsLauncher {}

class MockUploadAvatarUseCase extends Mock implements UploadAvatarUseCase {}

class MockAvatarImagePicker extends Mock implements AvatarImagePicker {}

class MockUpdateProfileUseCase extends Mock implements UpdateProfileUseCase {}

const _user = UserEntity(
  id: 'u1',
  name: 'Ana',
  lastname: 'Lopez',
  dni: '12345678',
  phone: '987654321',
  email: 'ana@test.com',
  image: '',
  role: 'CIUDADANO',
  stateAccount: 'HABILITADO',
  averageScore: 0.0,
  alertsAttended: 0,
);

const _disabledUser = UserEntity(
  id: 'u2',
  name: 'Luis',
  lastname: 'Diaz',
  dni: '87654321',
  phone: '912345678',
  email: 'luis@test.com',
  image: '',
  role: 'CIUDADANO',
  stateAccount: 'DESHABILITADO',
  averageScore: 0.0,
  alertsAttended: 0,
);

void main() {
  late MockSecureStorage storage;
  late MockRealtimeService realtimeService;
  late MockGetEmergencyContactsUseCase getContacts;
  late MockSaveEmergencyContactsUseCase saveContacts;

  setUp(() {
    storage = MockSecureStorage();
    realtimeService = MockRealtimeService();
    getContacts = MockGetEmergencyContactsUseCase();
    saveContacts = MockSaveEmergencyContactsUseCase();

    when(() => realtimeService.updatedProfiles)
        .thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    when(() => storage.getUserId()).thenAnswer((_) async => 'u1');
    when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => false);
    when(() => storage.setSendSmsOnAlert(any())).thenAnswer((_) async {});
    when(() => getContacts(any())).thenAnswer((_) async => const Right([]));
    when(() => storage.clearSession()).thenAnswer((_) async {});
    when(() => realtimeService.disconnect()).thenAnswer((_) async {});

    sl.registerLazySingleton<UploadAvatarUseCase>(
      () => MockUploadAvatarUseCase(),
    );
    sl.registerLazySingleton<AvatarImagePicker>(() => MockAvatarImagePicker());
    sl.registerLazySingleton<AvatarFileValidator>(
      () => const AvatarFileValidator(),
    );
    sl.registerLazySingleton<UpdateProfileUseCase>(
      () => MockUpdateProfileUseCase(),
    );
    sl.registerLazySingleton<PeruvianPhoneNormalizer>(
      () => const PeruvianPhoneNormalizer(),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  EmergencyContactsProvider buildContactsProvider() => EmergencyContactsProvider(
        getContactsUseCase: getContacts,
        saveContactsUseCase: saveContacts,
        storage: storage,
        contactPicker: MockDeviceContactPicker(),
        smsLauncher: MockSmsLauncher(),
        phoneNormalizer: const PeruvianPhoneNormalizer(),
        messageBuilder: const SmsMessageBuilder(),
        realtimeService: realtimeService,
      );

  MainNavigationProvider buildNavProvider(UserEntity user) =>
      MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
        initialUser: user,
      );

  Future<MainNavigationProvider> pumpProfile(
    WidgetTester tester, {
    UserEntity user = _user,
  }) async {
    final navProvider = buildNavProvider(user);
    final router = GoRouter(
      initialLocation: '/main',
      routes: [
        GoRoute(
          path: '/main',
          builder: (_, __) => MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: navProvider),
              ChangeNotifierProvider.value(value: buildContactsProvider()),
            ],
            child: const ProfileView(),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login page')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return navProvider;
  }

  group('ProfileView header and identity card', () {
    testWidgets('shows the header title, name, mono DNI and the enabled '
        'account pill', (tester) async {
      await pumpProfile(tester);

      expect(find.text('Mi perfil'), findsOneWidget);
      expect(find.text('Ana Lopez'), findsOneWidget);
      expect(find.textContaining('12345678'), findsWidgets);
      expect(find.text('Cuenta habilitada'), findsOneWidget);
    });

    testWidgets('shows the disabled account pill for a disabled account',
        (tester) async {
      await pumpProfile(tester, user: _disabledUser);

      expect(find.text('Cuenta deshabilitada'), findsOneWidget);
    });
  });

  group('Datos personales', () {
    testWidgets('shows the email and phone rows', (tester) async {
      await pumpProfile(tester);

      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('ana@test.com'), findsOneWidget);
      expect(find.text('Teléfono'), findsOneWidget);
      expect(find.text('987654321'), findsOneWidget);
    });

    testWidgets('tapping Editar opens the profile edit page', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar perfil'), findsOneWidget);
    });
  });

  group('Cerrar sesión', () {
    testWidgets('shows the confirmation dialog with the existing copy',
        (tester) async {
      await pumpProfile(tester);

      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Cerrar Sesión'), findsOneWidget);
      expect(
        find.text('¿Estás seguro de que deseas salir de tu cuenta?'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Salir'), findsOneWidget);
    });

    testWidgets('Salir logs out and navigates to the login route',
        (tester) async {
      await pumpProfile(tester);

      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      expect(find.text('Login page'), findsOneWidget);
      verify(() => storage.clearSession()).called(1);
    });
  });
}
