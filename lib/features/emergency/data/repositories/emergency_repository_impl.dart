import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/alert_type_entity.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../datasources/emergency_remote_datasource.dart';

class EmergencyRepositoryImpl implements EmergencyRepository {
  const EmergencyRepositoryImpl(this._dataSource);

  final EmergencyRemoteDataSource _dataSource;

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
  Future<Either<Failure, List<AlertTypeEntity>>> getAlertTypes() async {
    try {
      final models = await _dataSource.getAlertTypes();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Failed to load alert types',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, AlertEntity>> sendAlert({
    required double latitude,
    required double longitude,
    required String typeId,
  }) async {
    try {
      final model = await _dataSource.sendAlert(
        latitude: latitude,
        longitude: longitude,
        typeId: typeId,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Failed to send alert',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
