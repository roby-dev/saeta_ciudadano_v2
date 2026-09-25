import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/data/datasources/emergency_contacts_remote_datasource.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/data/models/emergency_contact_model.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/data/repositories/emergency_contacts_repository_impl.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/entities/emergency_contact_entity.dart';

class MockEmergencyContactsRemoteDataSource extends Mock
    implements EmergencyContactsRemoteDataSource {}

void main() {
  late MockEmergencyContactsRemoteDataSource dataSource;
  late EmergencyContactsRepositoryImpl repository;

  setUp(() {
    dataSource = MockEmergencyContactsRemoteDataSource();
    repository = EmergencyContactsRepositoryImpl(dataSource);
  });

  group('getContacts', () {
    test('returns Right with mapped entities on success', () async {
      when(() => dataSource.getContacts('u1')).thenAnswer(
        (_) async => const [
          EmergencyContactModel(name: 'Ana', phone: '987654321'),
        ],
      );

      final result = await repository.getContacts('u1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected a success'),
        (contacts) => expect(contacts, const [
          EmergencyContactEntity(name: 'Ana', phone: '987654321'),
        ]),
      );
    });

    test('returns NetworkFailure on connection error', () async {
      when(() => dataSource.getContacts('u1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/users/u1'),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repository.getContacts('u1');

      expect(result, isA<Left<Failure, List<EmergencyContactEntity>>>());
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected a failure'),
      );
    });

    test('returns ServerFailure with the backend message on a 4xx response',
        () async {
      when(() => dataSource.getContacts('u1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/users/u1'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/users/u1'),
            statusCode: 404,
            data: {'message': 'User not found'},
          ),
        ),
      );

      final result = await repository.getContacts('u1');

      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'User not found');
        },
        (_) => fail('expected a failure'),
      );
    });
  });

  group('saveContacts', () {
    test('sends entities mapped to models and returns Right on success',
        () async {
      when(() => dataSource.saveContacts('u1', [
            const EmergencyContactModel(name: 'Ana', phone: '987654321'),
          ])).thenAnswer(
        (_) async => const [
          EmergencyContactModel(name: 'Ana', phone: '987654321'),
        ],
      );

      final result = await repository.saveContacts(
        'u1',
        const [EmergencyContactEntity(name: 'Ana', phone: '987654321')],
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected a success'),
        (contacts) => expect(contacts, const [
          EmergencyContactEntity(name: 'Ana', phone: '987654321'),
        ]),
      );
    });

    test('returns ServerFailure enforcing the max-5 rule from the backend',
        () async {
      when(() => dataSource.saveContacts(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/users/u1'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/users/u1'),
            statusCode: 400,
            data: {'message': 'Maximum 5 emergency contacts are allowed'},
          ),
        ),
      );

      final result = await repository.saveContacts('u1', const []);

      result.fold(
        (failure) => expect(
          failure.message,
          'Maximum 5 emergency contacts are allowed',
        ),
        (_) => fail('expected a failure'),
      );
    });
  });
}
