import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dataSource);

  final ProfileRemoteDataSource _dataSource;

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
  Future<Either<Failure, UserEntity>> updateProfile({
    required String userId,
    required String name,
    required String lastname,
    required String phone,
    required String email,
  }) async {
    try {
      final model = await _dataSource.updateProfile(
        userId: userId,
        name: name,
        lastname: lastname,
        phone: phone,
        email: email,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      // Includes the 409 duplicate email/phone case: the backend's message
      // is surfaced as-is.
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Failed to update profile',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
