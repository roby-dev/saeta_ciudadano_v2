import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_request_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._dataSource);

  final AuthRemoteDataSource _dataSource;

  @override
  Future<Either<Failure, ({String token, String refreshToken, UserEntity user})>>
      login({required String email, required String password}) async {
    try {
      final response = await _dataSource.login(
        LoginRequestModel(email: email, password: password),
      );

      if (!response.ok) {
        return const Left(UnauthorizedFailure());
      }

      return Right((
        token: response.token,
        refreshToken: response.refreshToken,
        user: response.user.toEntity(),
      ));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      if (e.response?.statusCode == 401 ||
          e.response?.statusCode == 400) {
        final message =
            (e.response?.data as Map<String, dynamic>?)?['message']
                as String? ??
            'Invalid credentials';
        return Left(UnauthorizedFailure(message));
      }
      return Left(ServerFailure(
          e.response?.statusMessage ?? 'Server error'));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, String>> renewToken(String refreshToken) async {
    try {
      final token = await _dataSource.renewToken(refreshToken);
      return Right(token);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure());
      }
      return Left(ServerFailure(e.message ?? 'Token renewal failed'));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
