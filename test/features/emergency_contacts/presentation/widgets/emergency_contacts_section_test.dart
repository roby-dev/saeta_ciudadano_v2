import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/entities/emergency_contact_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/device_contact_picker.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_launcher.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_message_builder.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/usecases/get_emergency_contacts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/usecases/save_emergency_contacts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/presentation/providers/emergency_contacts_provider.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/presentation/widgets/emergency_contacts_section.dart';

class MockGetEmergencyContactsUseCase extends Mock
    implements GetEmergencyContactsUseCase {}

class MockSaveEmergencyContactsUseCase extends Mock
    implements SaveEmergencyContactsUseCase {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockDeviceContactPicker extends Mock implements DeviceContactPicker {}

class MockSmsLauncher extends Mock implements SmsLauncher {}

class MockRealtimeService extends Mock implements RealtimeService {}

const _ana = EmergencyContactEntity(name: 'Ana Lopez', phone: '987654321');
const _fiveContacts = [
  EmergencyContactEntity(name: 'A', phone: '911111111'),
  EmergencyContactEntity(name: 'B', phone: '922222222'),
  EmergencyContactEntity(name: 'C', phone: '933333333'),
  EmergencyContactEntity(name: 'D', phone: '944444444'),
  EmergencyContactEntity(name: 'E', phone: '955555555'),
];

void main() {
  late MockGetEmergencyContactsUseCase getContacts;
  late MockSaveEmergencyContactsUseCase saveContacts;
  late MockSecureStorage storage;
  late MockDeviceContactPicker contactPicker;
  late MockSmsLauncher smsLauncher;
  late MockRealtimeService realtimeService;

  setUp(() {
    getContacts = MockGetEmergencyContactsUseCase();
    saveContacts = MockSaveEmergencyContactsUseCase();
    storage = MockSecureStorage();
    contactPicker = MockDeviceContactPicker();
    smsLauncher = MockSmsLauncher();
    realtimeService = MockRealtimeService();
    when(() => storage.getUserId()).thenAnswer((_) async => 'u1');
    when(() => storage.setSendSmsOnAlert(any())).thenAnswer((_) async {});
    when(() => realtimeService.updatedProfiles)
        .thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
  });

  Future<EmergencyContactsProvider> buildProvider({
    required bool smsEnabled,
    List<EmergencyContactEntity> contacts = const [],
  }) async {
    when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => smsEnabled);
    when(() => getContacts('u1')).thenAnswer((_) async => Right(contacts));
    final provider = EmergencyContactsProvider(
      getContactsUseCase: getContacts,
      saveContactsUseCase: saveContacts,
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

  Future<void> pumpSection(
    WidgetTester tester,
    EmergencyContactsProvider provider,
  ) {
    return tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: EmergencyContactsSection()),
        ),
      ),
    );
  }

  testWidgets('shows the "N de 5 contactos" subtitle', (tester) async {
    final provider = await buildProvider(smsEnabled: false, contacts: const [_ana]);
    await pumpSection(tester, provider);

    expect(find.text('1 de 5 contactos'), findsOneWidget);
  });

  testWidgets('shows a contact row with initials, name and mono phone',
      (tester) async {
    final provider = await buildProvider(smsEnabled: false, contacts: const [_ana]);
    await pumpSection(tester, provider);

    expect(find.text('AL'), findsOneWidget);
    expect(find.text('Ana Lopez'), findsOneWidget);
    expect(find.text('987654321'), findsOneWidget);
    expect(find.byTooltip('Quitar contacto'), findsOneWidget);
  });

  testWidgets('shows the empty-state text when there are no contacts',
      (tester) async {
    final provider = await buildProvider(smsEnabled: false);
    await pumpSection(tester, provider);

    expect(
      find.text('No tienes contactos de emergencia agregados.'),
      findsOneWidget,
    );
  });

  testWidgets('the Agregar button is disabled at the 5-contact maximum',
      (tester) async {
    final provider =
        await buildProvider(smsEnabled: false, contacts: _fiveContacts);
    await pumpSection(tester, provider);

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Agregar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('the Agregar button is enabled below the maximum',
      (tester) async {
    final provider = await buildProvider(smsEnabled: false, contacts: const [_ana]);
    await pumpSection(tester, provider);

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Agregar'),
    );
    expect(button.onPressed, isNotNull);
  });

  group('SMS switch copy', () {
    testWidgets('shows the new title and the "with your contacts" subtitle '
        'when contacts exist', (tester) async {
      final provider = await buildProvider(smsEnabled: true, contacts: const [_ana]);
      await pumpSection(tester, provider);

      expect(find.text('Enviar SMS al reportar una alerta'), findsOneWidget);
      expect(
        find.text('Se abrirá el mensajero del teléfono con tus contactos.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the "add a contact" helper text and is disabled when '
        'there are no contacts', (tester) async {
      final provider = await buildProvider(smsEnabled: false);
      await pumpSection(tester, provider);

      expect(
        find.text('Agrega al menos un contacto para activar esta opción.'),
        findsOneWidget,
      );
      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.onChanged, isNull);
    });
  });
}
