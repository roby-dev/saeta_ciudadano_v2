import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/citizen_alert_entity.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../datasources/alerts_remote_datasource.dart';

class AlertsRepositoryImpl implements AlertsRepository {
  const AlertsRepositoryImpl(this._dataSource);

  final AlertsRemoteDataSource _dataSource;

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
  Future<Either<Failure, List<CitizenAlertEntity>>> getUserAlerts(String userId) async {
    try {
      final models = await _dataSource.getUserAlerts(userId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Error loading alerts',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, CitizenAlertEntity>> sendAlertFeedback({
    required String alertId,
    required String commentary,
    required double score,
  }) async {
    try {
      final model = await _dataSource.sendAlertFeedback(
        alertId: alertId,
        commentary: commentary,
        score: score,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Error submitting feedback',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
