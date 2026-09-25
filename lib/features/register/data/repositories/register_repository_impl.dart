import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/models/login_request_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/person_entity.dart';
import '../../domain/repositories/register_repository.dart';
import '../datasources/register_remote_datasource.dart';
import '../models/register_request_model.dart';

class RegisterRepositoryImpl implements RegisterRepository {
  const RegisterRepositoryImpl(
    this._dataSource,
    this._authDataSource,
  );

  final RegisterRemoteDataSource _dataSource;
  final AuthRemoteDataSource _authDataSource;

  String _extractErrorMessage(dynamic data, String defaultMessage) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is List) {
        return msg.map((e) => e.toString()).join('\n');
      }
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return defaultMessage;
  }

  @override
  Future<Either<Failure, PersonEntity>> lookupDni(String dni) async {
    try {
      final model = await _dataSource.lookupDni(dni);
      final entity = model.toEntity();
      if (entity.names.isEmpty && entity.lastname.isEmpty) {
        return const Left(ServerFailure('DNI not found'));
      }
      return Right(entity);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      if (e.response?.statusCode == 409) {
        final message = _extractErrorMessage(
          e.response?.data,
          'Ya existe una cuenta registrada con este DNI',
        );
        return Left(ServerFailure(message));
      }
      if (e.response?.statusCode == 404) {
        final message = _extractErrorMessage(
          e.response?.data,
          'DNI not found',
        );
        return Left(ServerFailure(message));
      }
      return Left(ServerFailure(
          e.response?.statusMessage ?? 'DNI lookup failed'));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, ({String token, String refreshToken, UserEntity user})>>
      register({
    required String dni,
    required String name,
    required String lastname,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dataSource.register(
        RegisterRequestModel(
          dni: dni,
          name: name,
          lastname: lastname,
          phone: phone,
          email: email,
          password: password,
        ),
      );

      if (!response.ok) {
        return const Left(ServerFailure('Registration failed'));
      }

      var token = response.token;
      var refreshToken = response.refreshToken;

      // Backend v2 creates the user but returns no tokens directly.
      // Auto-authenticate so the session is persisted seamlessly.
      if (token.isEmpty) {
        final loginResponse = await _authDataSource.login(
          LoginRequestModel(email: email, password: password),
        );
        token = loginResponse.token;
        refreshToken = loginResponse.refreshToken;
      }

      return Right((
        token: token,
        refreshToken: refreshToken,
        user: response.user.toEntity(),
      ));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 409) {
        final message = _extractErrorMessage(
          e.response?.data,
          'Registration error',
        );
        return Left(ServerFailure(message));
      }
      return Left(ServerFailure(
          e.response?.statusMessage ?? 'Server error'));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
