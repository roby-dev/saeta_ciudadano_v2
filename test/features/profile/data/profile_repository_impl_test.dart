import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/features/auth/data/models/user_model.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:saeta_ciudadano_v2/features/profile/data/repositories/profile_repository_impl.dart';

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

const _updatedModel = UserModel(
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

void main() {
  late MockProfileRemoteDataSource dataSource;
  late ProfileRepositoryImpl repository;

  setUp(() {
    dataSource = MockProfileRemoteDataSource();
    repository = ProfileRepositoryImpl(dataSource);
  });

  group('updateProfile', () {
    test('returns Right with the updated entity on success', () async {
      when(() => dataSource.updateProfile(
            userId: 'u1',
            name: 'Ana',
            lastname: 'Torres',
            phone: '987654321',
            email: 'ana@example.com',
          )).thenAnswer((_) async => _updatedModel);

      final result = await repository.updateProfile(
        userId: 'u1',
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected a success'),
        (user) => expect(user, _updatedModel.toEntity()),
      );
    });

    test('returns NetworkFailure on connection error', () async {
      when(() => dataSource.updateProfile(
            userId: 'u1',
            name: 'Ana',
            lastname: 'Torres',
            phone: '987654321',
            email: 'ana@example.com',
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/users/u1'),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repository.updateProfile(
        userId: 'u1',
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      expect(result, isA<Left<Failure, UserEntity>>());
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected a failure'),
      );
    });

    test('returns ServerFailure with the backend message on a 409 duplicate '
        'email/phone conflict', () async {
      when(() => dataSource.updateProfile(
            userId: 'u1',
            name: 'Ana',
            lastname: 'Torres',
            phone: '987654321',
            email: 'ana@example.com',
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/users/u1'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/users/u1'),
            statusCode: 409,
            data: {'message': 'Email already in use'},
          ),
        ),
      );

      final result = await repository.updateProfile(
        userId: 'u1',
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Email already in use');
        },
        (_) => fail('expected a failure'),
      );
    });

    test('returns UnknownFailure on an unexpected error', () async {
      when(() => dataSource.updateProfile(
            userId: 'u1',
            name: 'Ana',
            lastname: 'Torres',
            phone: '987654321',
            email: 'ana@example.com',
          )).thenThrow(Exception('boom'));

      final result = await repository.updateProfile(
        userId: 'u1',
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      result.fold(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('expected a failure'),
      );
    });
  });

  group('uploadAvatar', () {
    test('returns Right with the updated entity on success', () async {
      when(() => dataSource.uploadAvatar(
            userId: 'u1',
            filePath: '/tmp/avatar.jpg',
          )).thenAnswer((_) async => _updatedModel);

      final result = await repository.uploadAvatar(
        userId: 'u1',
        filePath: '/tmp/avatar.jpg',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected a success'),
        (user) => expect(user, _updatedModel.toEntity()),
      );
    });

    test('returns NetworkFailure on connection error', () async {
      when(() => dataSource.uploadAvatar(
            userId: 'u1',
            filePath: '/tmp/avatar.jpg',
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/uploads/u1'),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repository.uploadAvatar(
        userId: 'u1',
        filePath: '/tmp/avatar.jpg',
      );

      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected a failure'),
      );
    });

    test('returns ServerFailure with the backend message on a 400 bad '
        'extension/size rejection', () async {
      when(() => dataSource.uploadAvatar(
            userId: 'u1',
            filePath: '/tmp/avatar.jpg',
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/uploads/u1'),
          response: Response(
            requestOptions: RequestOptions(path: '/v1/uploads/u1'),
            statusCode: 400,
            data: {'message': 'Invalid image extension .pdf'},
          ),
        ),
      );

      final result = await repository.uploadAvatar(
        userId: 'u1',
        filePath: '/tmp/avatar.jpg',
      );

      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'Invalid image extension .pdf');
        },
        (_) => fail('expected a failure'),
      );
    });

    test('returns UnknownFailure on an unexpected error', () async {
      when(() => dataSource.uploadAvatar(
            userId: 'u1',
            filePath: '/tmp/avatar.jpg',
          )).thenThrow(Exception('boom'));

      final result = await repository.uploadAvatar(
        userId: 'u1',
        filePath: '/tmp/avatar.jpg',
      );

      result.fold(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('expected a failure'),
      );
    });
  });
}
