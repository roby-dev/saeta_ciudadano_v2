import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:saeta_ciudadano_v2/features/profile/presentation/providers/profile_edit_provider.dart';

class MockUpdateProfileUseCase extends Mock implements UpdateProfileUseCase {}

const _originalUser = UserEntity(
  id: 'u1',
  name: 'Ana',
  lastname: 'Torres',
  dni: '12345678',
  phone: '987654321',
  email: 'ana@example.com',
  image: '',
  role: 'CIUDADANO',
  stateAccount: 'HABILITADO',
  averageScore: 0,
  alertsAttended: 0,
);

const _updatedUser = UserEntity(
  id: 'u1',
  name: 'Ana María',
  lastname: 'Torres',
  dni: '12345678',
  phone: '912345678',
  email: 'ana.maria@example.com',
  image: '',
  role: 'CIUDADANO',
  stateAccount: 'HABILITADO',
  averageScore: 0,
  alertsAttended: 0,
);

void main() {
  late MockUpdateProfileUseCase useCase;
  UserEntity? capturedByCallback;

  ProfileEditProvider buildProvider() {
    return ProfileEditProvider(
      updateProfileUseCase: useCase,
      phoneNormalizer: const PeruvianPhoneNormalizer(),
      currentUser: _originalUser,
      onUpdated: (user) => capturedByCallback = user,
    );
  }

  setUp(() {
    useCase = MockUpdateProfileUseCase();
    capturedByCallback = null;
  });

  group('field validation', () {
    test('validateName rejects an empty or whitespace-only value', () {
      final provider = buildProvider();

      expect(provider.validateName(''), isNotNull);
      expect(provider.validateName('   '), isNotNull);
      expect(provider.validateName('Ana'), isNull);
    });

    test('validatePhone rejects an empty value and a non-normalizable '
        'number', () {
      final provider = buildProvider();

      expect(provider.validatePhone(''), isNotNull);
      expect(provider.validatePhone('123'), isNotNull);
      expect(provider.validatePhone('+1 987 654 321'), isNotNull);
      expect(provider.validatePhone('+51 987 654 321'), isNull);
      expect(provider.validatePhone('987654321'), isNull);
    });

    test('validateEmail rejects an empty value and an invalid format', () {
      final provider = buildProvider();

      expect(provider.validateEmail(''), isNotNull);
      expect(provider.validateEmail('not-an-email'), isNotNull);
      expect(provider.validateEmail('ana@example.com'), isNull);
    });
  });

  group('save', () {
    test('rejects an empty name without calling the use case', () async {
      final provider = buildProvider();

      final result = await provider.save(
        name: '',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => useCase(
            any(),
            name: any(named: 'name'),
            lastname: any(named: 'lastname'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
          ));
    });

    test('rejects an empty lastname without calling the use case', () async {
      final provider = buildProvider();

      final result = await provider.save(
        name: 'Ana',
        lastname: '',
        phone: '987654321',
        email: 'ana@example.com',
      );

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => useCase(
            any(),
            name: any(named: 'name'),
            lastname: any(named: 'lastname'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
          ));
    });

    test('rejects a phone that cannot be normalized without calling the '
        'use case', () async {
      final provider = buildProvider();

      final result = await provider.save(
        name: 'Ana',
        lastname: 'Torres',
        phone: 'not-a-phone',
        email: 'ana@example.com',
      );

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => useCase(
            any(),
            name: any(named: 'name'),
            lastname: any(named: 'lastname'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
          ));
    });

    test('rejects an invalid email without calling the use case', () async {
      final provider = buildProvider();

      final result = await provider.save(
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'not-an-email',
      );

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => useCase(
            any(),
            name: any(named: 'name'),
            lastname: any(named: 'lastname'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
          ));
    });

    test('sends the normalized 9-digit phone to the use case', () async {
      when(() => useCase(
            'u1',
            name: 'Ana María',
            lastname: 'Torres',
            phone: '912345678',
            email: 'ana.maria@example.com',
          )).thenAnswer((_) async => const Right(_updatedUser));
      final provider = buildProvider();

      await provider.save(
        name: 'Ana María',
        lastname: 'Torres',
        phone: '+51 912 345 678',
        email: 'ana.maria@example.com',
      );

      verify(() => useCase(
            'u1',
            name: 'Ana María',
            lastname: 'Torres',
            phone: '912345678',
            email: 'ana.maria@example.com',
          )).called(1);
    });

    test('on success, updates currentUser, invokes onUpdated and clears '
        'the error and saving state', () async {
      when(() => useCase(
            'u1',
            name: 'Ana María',
            lastname: 'Torres',
            phone: '912345678',
            email: 'ana.maria@example.com',
          )).thenAnswer((_) async => const Right(_updatedUser));
      final provider = buildProvider();

      final result = await provider.save(
        name: 'Ana María',
        lastname: 'Torres',
        phone: '+51 912 345 678',
        email: 'ana.maria@example.com',
      );

      expect(result, isTrue);
      expect(provider.currentUser, _updatedUser);
      expect(provider.errorMessage, isNull);
      expect(provider.isSaving, isFalse);
      expect(capturedByCallback, _updatedUser);
    });

    test('on failure, keeps the old user, exposes the backend message and '
        'clears the saving flag', () async {
      when(() => useCase(
            'u1',
            name: 'Ana María',
            lastname: 'Torres',
            phone: '912345678',
            email: 'ana.maria@example.com',
          )).thenAnswer(
        (_) async => const Left(ServerFailure('Email already in use')),
      );
      final provider = buildProvider();

      final result = await provider.save(
        name: 'Ana María',
        lastname: 'Torres',
        phone: '+51 912 345 678',
        email: 'ana.maria@example.com',
      );

      expect(result, isFalse);
      expect(provider.currentUser, _originalUser);
      expect(provider.errorMessage, 'Email already in use');
      expect(provider.isSaving, isFalse);
      expect(capturedByCallback, isNull);
    });

    test('sets isSaving to true while the use case is in flight', () async {
      final completer = Completer<Either<Failure, UserEntity>>();
      when(() => useCase(
            'u1',
            name: 'Ana María',
            lastname: 'Torres',
            phone: '912345678',
            email: 'ana.maria@example.com',
          )).thenAnswer((_) => completer.future);
      final provider = buildProvider();

      final future = provider.save(
        name: 'Ana María',
        lastname: 'Torres',
        phone: '+51 912 345 678',
        email: 'ana.maria@example.com',
      );
      await Future<void>.delayed(Duration.zero);
      expect(provider.isSaving, isTrue);

      completer.complete(const Right(_updatedUser));
      await future;
      expect(provider.isSaving, isFalse);
    });
  });
}
