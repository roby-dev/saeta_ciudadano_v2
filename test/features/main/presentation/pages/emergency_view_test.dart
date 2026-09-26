import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/get_user_alerts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/send_alert_feedback_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/providers/alerts_provider.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency/domain/entities/alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency/domain/entities/alert_type_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency/domain/usecases/get_alert_types_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency/domain/usecases/send_alert_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency/presentation/providers/emergency_provider.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/entities/emergency_contact_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/device_contact_picker.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_launcher.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_message_builder.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/usecases/get_emergency_contacts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/usecases/save_emergency_contacts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/presentation/providers/emergency_contacts_provider.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/pages/emergency_view.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/providers/main_navigation_provider.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/widgets/emergency_type_card.dart';

class MockGetAlertTypesUseCase extends Mock implements GetAlertTypesUseCase {}

class MockSendAlertUseCase extends Mock implements SendAlertUseCase {}

class MockGetUserAlertsUseCase extends Mock implements GetUserAlertsUseCase {}

class MockSendAlertFeedbackUseCase extends Mock
    implements SendAlertFeedbackUseCase {}

class MockGetEmergencyContactsUseCase extends Mock
    implements GetEmergencyContactsUseCase {}

class MockSaveEmergencyContactsUseCase extends Mock
    implements SaveEmergencyContactsUseCase {}

class MockDeviceContactPicker extends Mock implements DeviceContactPicker {}

class MockSmsLauncher extends Mock implements SmsLauncher {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockRealtimeService extends Mock implements RealtimeService {}

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

const _ana = EmergencyContactEntity(name: 'Ana', phone: '987654321');
const _luis = EmergencyContactEntity(name: 'Luis', phone: '912345678');

void main() {
  late MockGetAlertTypesUseCase getAlertTypesUseCase;
  late MockSendAlertUseCase sendAlertUseCase;
  late MockGetUserAlertsUseCase getUserAlertsUseCase;
  late MockSendAlertFeedbackUseCase sendAlertFeedbackUseCase;
  late MockGetEmergencyContactsUseCase getContactsUseCase;
  late MockSaveEmergencyContactsUseCase saveContactsUseCase;
  late MockDeviceContactPicker contactPicker;
  late MockSmsLauncher smsLauncher;
  late MockSecureStorage storage;
  late MockRealtimeService realtimeService;

  setUp(() {
    // EmergencyProvider.sendAlert() calls the real Geolocator plugin
    // (isLocationServiceEnabled/getCurrentPosition) to resolve GPS
    // coordinates; with no platform binding registered under `flutter
    // test`, that call would otherwise hang forever (never rejects), so it
    // is mocked to report location services as disabled — the code's own
    // _fallbackPosition() then kicks in immediately, same as on a real
    // device with location off.
    TestWidgetsFlutterBinding.ensureInitialized();
    const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (call) async {
      if (call.method == 'isLocationServiceEnabled') return false;
      return null;
    });

    getAlertTypesUseCase = MockGetAlertTypesUseCase();
    sendAlertUseCase = MockSendAlertUseCase();
    getUserAlertsUseCase = MockGetUserAlertsUseCase();
    sendAlertFeedbackUseCase = MockSendAlertFeedbackUseCase();
    getContactsUseCase = MockGetEmergencyContactsUseCase();
    saveContactsUseCase = MockSaveEmergencyContactsUseCase();
    contactPicker = MockDeviceContactPicker();
    smsLauncher = MockSmsLauncher();
    storage = MockSecureStorage();
    realtimeService = MockRealtimeService();

    when(() => realtimeService.updatedAlerts)
        .thenAnswer((_) => const Stream.empty());
    when(() => realtimeService.updatedProfiles)
        .thenAnswer((_) => const Stream.empty());
    when(() => getAlertTypesUseCase())
        .thenAnswer((_) async => const Right([
              AlertTypeEntity(id: 't-robo', name: 'Robo'),
            ]));
    when(() => smsLauncher.launch(
          phoneNumbers: any(named: 'phoneNumbers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async {});
  });

  EmergencyProvider buildEmergencyProvider() => EmergencyProvider(
        getAlertTypesUseCase: getAlertTypesUseCase,
        sendAlertUseCase: sendAlertUseCase,
      );

  AlertsProvider buildAlertsProvider() => AlertsProvider(
        getUserAlertsUseCase: getUserAlertsUseCase,
        sendAlertFeedbackUseCase: sendAlertFeedbackUseCase,
        realtimeService: realtimeService,
      );

  Future<EmergencyContactsProvider> buildContactsProvider({
    required bool smsEnabled,
    List<EmergencyContactEntity> contacts = const [],
  }) async {
    when(() => storage.getUserId()).thenAnswer((_) async => 'u1');
    when(() => storage.getSendSmsOnAlert())
        .thenAnswer((_) async => smsEnabled);
    when(() => storage.setSendSmsOnAlert(any())).thenAnswer((_) async {});
    when(() => getContactsUseCase('u1'))
        .thenAnswer((_) async => Right(contacts));
    final provider = EmergencyContactsProvider(
      getContactsUseCase: getContactsUseCase,
      saveContactsUseCase: saveContactsUseCase,
      storage: storage,
      contactPicker: contactPicker,
      smsLauncher: smsLauncher,
      phoneNormalizer: const PeruvianPhoneNormalizer(),
      messageBuilder: const SmsMessageBuilder(),
      realtimeService: realtimeService,
    );
    await provider.load();
    return provider;
  }

  MainNavigationProvider buildNavProvider() => MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
        initialUser: _user,
      );

  Future<void> pumpView(
    WidgetTester tester, {
    required EmergencyProvider emergencyProvider,
    required AlertsProvider alertsProvider,
    required EmergencyContactsProvider contactsProvider,
    required MainNavigationProvider navProvider,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: emergencyProvider),
          ChangeNotifierProvider.value(value: alertsProvider),
          ChangeNotifierProvider.value(value: contactsProvider),
          ChangeNotifierProvider.value(value: navProvider),
        ],
        child: const MaterialApp(home: EmergencyView()),
      ),
    );
  }

  group('EmergencyView header', () {
    testWidgets('shows the brand mark and a Spanish greeting with initials',
        (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      final navProvider = buildNavProvider();
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: navProvider,
      );
      await tester.pump();

      expect(find.text('SAETA'), findsOneWidget);
      expect(find.text('Ciudadano'), findsOneWidget);
      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('AL'), findsOneWidget);
    });

    testWidgets('tapping the avatar switches to the Perfil tab',
        (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      final navProvider = buildNavProvider();
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: navProvider,
      );
      await tester.pump();

      await tester.tap(find.text('AL'));
      await tester.pump();

      expect(navProvider.currentIndex, 2);
    });
  });

  group('EmergencyView incident grid', () {
    testWidgets('shows the 6 single-line Spanish labels in the canvas order',
        (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      final titles = tester
          .widgetList<EmergencyTypeCard>(find.byType(EmergencyTypeCard))
          .map((c) => c.title)
          .toList();
      expect(titles, [
        'Robo',
        'Incendio',
        'Accidente de tránsito',
        'Pandillaje',
        'Violencia familiar',
        'Otro',
      ]);
    });
  });

  group('EmergencyView SMS row', () {
    testWidgets('shows "Activado · N contactos" when enabled with contacts',
        (tester) async {
      final contactsProvider = await buildContactsProvider(
        smsEnabled: true,
        contacts: const [_ana, _luis],
      );
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      expect(find.text('SMS a contactos de emergencia'), findsOneWidget);
      expect(find.text('Activado · 2 contactos'), findsOneWidget);
    });

    testWidgets('shows "Desactivado" when there are no contacts',
        (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      expect(find.text('Desactivado'), findsOneWidget);
    });

    testWidgets('tapping the row switches to the Perfil tab', (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      final navProvider = buildNavProvider();
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: navProvider,
      );
      await tester.pump();

      await tester.ensureVisible(find.text('SMS a contactos de emergencia'));
      await tester.tap(find.text('SMS a contactos de emergencia'));
      await tester.pump();

      expect(navProvider.currentIndex, 2);
    });
  });

  group('EmergencyView report confirmation sheet', () {
    testWidgets(
        'tapping an incident tile opens the sheet with a lowercase title '
        'and the GPS placeholder', (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Robo'));
      await tester.tap(find.text('Robo'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar robo'), findsOneWidget);
      expect(find.text('Confirma para alertar a la central de seguridad.'),
          findsOneWidget);
      expect(find.text('Ubicación GPS'), findsOneWidget);
      expect(find.text('Se obtendrá al enviar'), findsOneWidget);
      expect(find.textContaining('Se abrirá el mensajero'), findsNothing);
    });

    testWidgets('shows the SMS line only when SMS is enabled with contacts',
        (tester) async {
      final contactsProvider = await buildContactsProvider(
        smsEnabled: true,
        contacts: const [_ana, _luis],
      );
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Incendio'));
      await tester.tap(find.text('Incendio'));
      await tester.pumpAndSettle();

      expect(find.text('Se abrirá el mensajero para 2 contactos'),
          findsOneWidget);
    });

    testWidgets('Cancelar dismisses the sheet without sending an alert',
        (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Robo'));
      await tester.tap(find.text('Robo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar robo'), findsNothing);
      verifyNever(() => sendAlertUseCase(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            typeId: any(named: 'typeId'),
          ));
    });

    testWidgets(
        'Enviar alerta sends the alert and shows the restyled success '
        'dialog', (tester) async {
      when(() => sendAlertUseCase(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            typeId: any(named: 'typeId'),
          )).thenAnswer((_) async => const Right(AlertEntity(
            id: 'a1',
            latitude: -12.0,
            longitude: -77.0,
            typeId: 't-robo',
            stateId: 's-pendiente',
            creationDate: '2026-09-26T00:00:00.000Z',
          )));
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Robo'));
      await tester.tap(find.text('Robo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enviar alerta'));
      await tester.tap(find.text('Enviar alerta'));
      // Not pumpAndSettle: the "isSending" overlay's CircularProgressIndicator
      // animates indefinitely, so pumpAndSettle would never converge even
      // though the (mocked) async chain resolves almost immediately. Bounded
      // pumps instead give the sheet-close animation and the async
      // sendAlert/refresh/SMS chain enough real time to finish.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      verify(() => sendAlertUseCase(
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            typeId: any(named: 'typeId'),
          )).called(1);
      expect(find.text('Alerta enviada'), findsOneWidget);
    });

    testWidgets('the SOS button still reports the Emergencia type',
        (tester) async {
      final contactsProvider =
          await buildContactsProvider(smsEnabled: false);
      await pumpView(
        tester,
        emergencyProvider: buildEmergencyProvider(),
        alertsProvider: buildAlertsProvider(),
        contactsProvider: contactsProvider,
        navProvider: buildNavProvider(),
      );
      await tester.pump();

      await tester.tap(find.text('SOS'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar emergencia'), findsOneWidget);
    });
  });
}
