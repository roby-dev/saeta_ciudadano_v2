import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/citizen_alert_entity.dart';

abstract interface class AlertsRepository {
  Future<Either<Failure, List<CitizenAlertEntity>>> getUserAlerts(String userId);

  Future<Either<Failure, CitizenAlertEntity>> sendAlertFeedback({
    required String alertId,
    required String commentary,
    required double score,
  });
}
