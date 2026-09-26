import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
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

class MockGetEmergencyContactsUseCase extends Mock
    implements GetEmergencyContactsUseCase {}

class MockSaveEmergencyContactsUseCase extends Mock
    implements SaveEmergencyContactsUseCase {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockDeviceContactPicker extends Mock implements DeviceContactPicker {}

class MockSmsLauncher extends Mock implements SmsLauncher {}

class MockRealtimeService extends Mock implements RealtimeService {}

const _userId = 'u1';
const _ana = EmergencyContactEntity(name: 'Ana', phone: '987654321');
const _luis = EmergencyContactEntity(name: 'Luis', phone: '912345678');

void main() {
  late MockGetEmergencyContactsUseCase getContacts;
  late MockSaveEmergencyContactsUseCase saveContacts;
  late MockSecureStorage storage;
  late MockDeviceContactPicker contactPicker;
  late MockSmsLauncher smsLauncher;
  late MockRealtimeService realtimeService;
  late StreamController<Map<String, dynamic>> profileController;

  EmergencyContactsProvider buildProvider() {
    return EmergencyContactsProvider(
      getContactsUseCase: getContacts,
      saveContactsUseCase: saveContacts,
      storage: storage,
      contactPicker: contactPicker,
      smsLauncher: smsLauncher,
      phoneNormalizer: const PeruvianPhoneNormalizer(),
      messageBuilder: const SmsMessageBuilder(),
      realtimeService: realtimeService,
    );
  }

  setUpAll(() {
    registerFallbackValue(const <EmergencyContactEntity>[]);
  });

  setUp(() {
    getContacts = MockGetEmergencyContactsUseCase();
    saveContacts = MockSaveEmergencyContactsUseCase();
    storage = MockSecureStorage();
    contactPicker = MockDeviceContactPicker();
    smsLauncher = MockSmsLauncher();
    realtimeService = MockRealtimeService();
    profileController = StreamController<Map<String, dynamic>>.broadcast();

    when(() => storage.getUserId()).thenAnswer((_) async => _userId);
    when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => false);
    when(() => storage.setSendSmsOnAlert(any())).thenAnswer((_) async {});
    when(() => realtimeService.updatedProfiles)
        .thenAnswer((_) => profileController.stream);
  });

  tearDown(() {
    profileController.close();
  });

  group('load', () {
    test('populates contacts and the sms preference on success', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => true);

      final provider = buildProvider();
      await provider.load();

      expect(provider.contacts, [_ana]);
      expect(provider.sendSmsOnAlert, isTrue);
      expect(provider.isLoading, isFalse);
      verifyNever(() => storage.setSendSmsOnAlert(false));
    });

    test('forces the sms preference off and persists it when there are no '
        'contacts, even if it was previously stored as true', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([]));
      when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => true);

      final provider = buildProvider();
      await provider.load();

      expect(provider.contacts, isEmpty);
      expect(provider.sendSmsOnAlert, isFalse);
      verify(() => storage.setSendSmsOnAlert(false)).called(1);
    });

    test('sets an error message when fetching contacts fails', () async {
      when(() => getContacts(_userId)).thenAnswer(
        (_) async => const Left(ServerFailure('boom')),
      );

      final provider = buildProvider();
      await provider.load();

      expect(provider.contacts, isEmpty);
      expect(provider.errorMessage, 'boom');
    });
  });

  group('addContactFromPicker', () {
    test('rejects when already at the 5-contact maximum without opening '
        'the picker', () async {
      when(() => getContacts(_userId)).thenAnswer(
        (_) async => const Right([
          EmergencyContactEntity(name: 'A', phone: '911111111'),
          EmergencyContactEntity(name: 'B', phone: '922222222'),
          EmergencyContactEntity(name: 'C', phone: '933333333'),
          EmergencyContactEntity(name: 'D', phone: '944444444'),
          EmergencyContactEntity(name: 'E', phone: '955555555'),
        ]),
      );
      final provider = buildProvider();
      await provider.load();

      final result = await provider.addContactFromPicker();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => contactPicker.pickContactPhoneNumber());
    });

    test('returns false without an error when the user cancels the picker',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([]));
      when(() => contactPicker.pickContactPhoneNumber())
          .thenAnswer((_) async => null);
      final provider = buildProvider();
      await provider.load();

      final result = await provider.addContactFromPicker();

      expect(result, isFalse);
      expect(provider.errorMessage, isNull);
      verifyNever(() => saveContacts(any(), any()));
    });

    test('rejects a phone number that cannot be normalized to 9 digits',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([]));
      when(() => contactPicker.pickContactPhoneNumber()).thenAnswer(
        (_) async =>
            const PickedContact(name: 'Foreign', phoneNumber: '+1 987 654 321'),
      );
      final provider = buildProvider();
      await provider.load();

      final result = await provider.addContactFromPicker();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => saveContacts(any(), any()));
    });

    test('rejects a contact whose normalized phone is already added',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => contactPicker.pickContactPhoneNumber()).thenAnswer(
        (_) async => const PickedContact(
          name: 'Ana Duplicate',
          phoneNumber: '+51 987 654 321',
        ),
      );
      final provider = buildProvider();
      await provider.load();

      final result = await provider.addContactFromPicker();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => saveContacts(any(), any()));
    });

    test('normalizes the picked phone, saves the full list, and updates '
        'state from the backend response', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => contactPicker.pickContactPhoneNumber()).thenAnswer(
        (_) async => const PickedContact(
          name: 'Luis',
          phoneNumber: '+51 912 345 678',
        ),
      );
      when(() => saveContacts(_userId, [_ana, _luis]))
          .thenAnswer((_) async => const Right([_ana, _luis]));
      final provider = buildProvider();
      await provider.load();

      final result = await provider.addContactFromPicker();

      expect(result, isTrue);
      expect(provider.contacts, [_ana, _luis]);
      expect(provider.errorMessage, isNull);
    });

    test('sets an error and keeps the previous list when saving fails',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => contactPicker.pickContactPhoneNumber()).thenAnswer(
        (_) async =>
            const PickedContact(name: 'Luis', phoneNumber: '912345678'),
      );
      when(() => saveContacts(_userId, [_ana, _luis])).thenAnswer(
        (_) async => const Left(ServerFailure('save failed')),
      );
      final provider = buildProvider();
      await provider.load();

      final result = await provider.addContactFromPicker();

      expect(result, isFalse);
      expect(provider.errorMessage, 'save failed');
      expect(provider.contacts, [_ana]);
    });
  });

  group('removeContact', () {
    test('persists the list without the removed contact', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana, _luis]));
      when(() => saveContacts(_userId, [_luis]))
          .thenAnswer((_) async => const Right([_luis]));
      final provider = buildProvider();
      await provider.load();

      final result = await provider.removeContact(_ana);

      expect(result, isTrue);
      expect(provider.contacts, [_luis]);
    });

    test('forces the sms preference off when the last contact is removed',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => true);
      when(() => saveContacts(_userId, []))
          .thenAnswer((_) async => const Right([]));
      final provider = buildProvider();
      await provider.load();
      expect(provider.sendSmsOnAlert, isTrue);

      await provider.removeContact(_ana);

      expect(provider.contacts, isEmpty);
      expect(provider.sendSmsOnAlert, isFalse);
      verify(() => storage.setSendSmsOnAlert(false)).called(1);
    });
  });

  group('setSendSmsOnAlert', () {
    test('persists true when there are contacts', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      final provider = buildProvider();
      await provider.load();

      await provider.setSendSmsOnAlert(true);

      expect(provider.sendSmsOnAlert, isTrue);
      verify(() => storage.setSendSmsOnAlert(true)).called(1);
    });

    test('stays false when there are no contacts, even if requested true',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([]));
      final provider = buildProvider();
      await provider.load();

      await provider.setSendSmsOnAlert(true);

      expect(provider.sendSmsOnAlert, isFalse);
      verify(() => storage.setSendSmsOnAlert(false)).called(1);
    });
  });

  group('sendSmsForAlert', () {
    test('does not launch the composer when the preference is off',
        () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      final provider = buildProvider();
      await provider.load();

      await provider.sendSmsForAlert(
        alertTypeName: 'Robo',
        latitude: 1,
        longitude: 2,
      );

      verifyNever(
        () => smsLauncher.launch(
          phoneNumbers: any(named: 'phoneNumbers'),
          body: any(named: 'body'),
        ),
      );
    });

    test('does not launch the composer when there are no contacts (even '
        'if the preference were somehow on)', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([]));
      final provider = buildProvider();
      await provider.load();

      await provider.sendSmsForAlert(
        alertTypeName: 'Robo',
        latitude: 1,
        longitude: 2,
      );

      verifyNever(
        () => smsLauncher.launch(
          phoneNumbers: any(named: 'phoneNumbers'),
          body: any(named: 'body'),
        ),
      );
    });

    test('launches the composer with all contact numbers and the built '
        'message when enabled with contacts', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana, _luis]));
      when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => true);
      when(() => smsLauncher.launch(
            phoneNumbers: any(named: 'phoneNumbers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async {});
      final provider = buildProvider();
      await provider.load();

      await provider.sendSmsForAlert(
        alertTypeName: 'Robo',
        latitude: -12.0,
        longitude: -77.0,
      );

      final captured = verify(() => smsLauncher.launch(
            phoneNumbers: captureAny(named: 'phoneNumbers'),
            body: captureAny(named: 'body'),
          )).captured;
      expect(captured[0], ['987654321', '912345678']);
      expect(
        captured[1],
        'Hola, tengo o acabo de presenciar un incidente del tipo Robo, '
        'por favor mantente alerta. '
        'Mi ubicación: https://maps.google.com/?q=-12.0,-77.0',
      );
    });

    test('never throws when the launcher fails, so the alert flow is '
        'unaffected', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => true);
      when(() => smsLauncher.launch(
            phoneNumbers: any(named: 'phoneNumbers'),
            body: any(named: 'body'),
          )).thenThrow(const SmsLaunchException('no sms app'));
      final provider = buildProvider();
      await provider.load();

      await expectLater(
        provider.sendSmsForAlert(
          alertTypeName: 'Robo',
          latitude: 1,
          longitude: 2,
        ),
        completes,
      );
    });
  });

  group('updatedProfile', () {
    test('replaces the contact list when the payload id matches and '
        'carries emergencyContacts', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      final provider = buildProvider();
      await provider.load();

      profileController.add({
        'id': _userId,
        'emergencyContacts': [
          {'name': 'Luis', 'phone': '912345678'},
        ],
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.contacts, [_luis]);
      verifyNever(() => saveContacts(any(), any()));
    });

    test('ignores an event for a different userId', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      final provider = buildProvider();
      await provider.load();

      profileController.add({
        'id': 'other-user',
        'emergencyContacts': <Map<String, dynamic>>[],
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.contacts, [_ana]);
    });

    test('leaves the list untouched when the payload has no '
        'emergencyContacts key', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      final provider = buildProvider();
      await provider.load();

      profileController.add({'id': _userId, 'name': 'Ana renamed'});
      await Future<void>.delayed(Duration.zero);

      expect(provider.contacts, [_ana]);
    });

    test('forces the sms-on-alert preference off and persists it when the '
        'new list is empty', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      when(() => storage.getSendSmsOnAlert()).thenAnswer((_) async => true);
      final provider = buildProvider();
      await provider.load();
      expect(provider.sendSmsOnAlert, isTrue);

      profileController.add({
        'id': _userId,
        'emergencyContacts': <Map<String, dynamic>>[],
      });
      await Future<void>.delayed(Duration.zero);

      expect(provider.contacts, isEmpty);
      expect(provider.sendSmsOnAlert, isFalse);
      verify(() => storage.setSendSmsOnAlert(false)).called(1);
    });

    test('cancels the subscription on dispose', () async {
      when(() => getContacts(_userId))
          .thenAnswer((_) async => const Right([_ana]));
      final provider = buildProvider();
      await provider.load();

      provider.dispose();
      profileController.add({
        'id': _userId,
        'emergencyContacts': [
          {'name': 'Luis', 'phone': '912345678'},
        ],
      });
      await Future<void>.delayed(Duration.zero);

      // A notifyListeners() call after dispose() throws in debug mode, so
      // the absence of an exception here proves the subscription was
      // cancelled.
    });
  });
}
