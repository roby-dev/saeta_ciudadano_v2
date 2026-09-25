import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/citizen_alert_entity.dart';
import '../repositories/alerts_repository.dart';

class GetUserAlertsUseCase {
  const GetUserAlertsUseCase(this._repository);

  final AlertsRepository _repository;

  Future<Either<Failure, List<CitizenAlertEntity>>> call(String userId) {
    return _repository.getUserAlerts(userId);
  }
}
