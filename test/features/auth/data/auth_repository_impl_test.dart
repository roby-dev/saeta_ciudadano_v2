import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:saeta_ciudadano_v2/features/auth/data/models/user_model.dart';
import 'package:saeta_ciudadano_v2/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

const _user = UserModel(
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

/// `getCurrentUser()` is the T6 auto-login validation call. `login`/
/// `renewToken` are untested here, consistent with this repository's
/// pre-existing (T1) convention of no dedicated coverage for them.
void main() {
  late MockAuthRemoteDataSource dataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    dataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(dataSource);
  });

  test('returns Right with the mapped entity on success', () async {
    when(() => dataSource.getCurrentUser()).thenAnswer((_) async => _user);

    final result = await repository.getCurrentUser();

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected Right'),
      (user) => expect(user.id, 'u1'),
    );
  });

  test('returns NetworkFailure on a connection error', () async {
    when(() => dataSource.getCurrentUser()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/v1/auth/me'),
        type: DioExceptionType.connectionError,
      ),
    );

    final result = await repository.getCurrentUser();

    expect(result, const Left<Failure, dynamic>(NetworkFailure()));
  });

  test('returns UnauthorizedFailure on a 401 (session unrecoverable)',
      () async {
    when(() => dataSource.getCurrentUser()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/v1/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/auth/me'),
          statusCode: 401,
          data: {'message': 'Unauthorized'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final result = await repository.getCurrentUser();

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<UnauthorizedFailure>()),
      (_) => fail('expected Left'),
    );
  });

  test('returns ServerFailure on a non-401 server error', () async {
    when(() => dataSource.getCurrentUser()).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/v1/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/auth/me'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    final result = await repository.getCurrentUser();

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
