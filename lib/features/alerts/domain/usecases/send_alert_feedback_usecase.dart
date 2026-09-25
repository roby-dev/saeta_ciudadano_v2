import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/citizen_alert_entity.dart';
import '../repositories/alerts_repository.dart';

class SendAlertFeedbackUseCase {
  const SendAlertFeedbackUseCase(this._repository);

  final AlertsRepository _repository;

  Future<Either<Failure, CitizenAlertEntity>> call({
    required String alertId,
    required String commentary,
    required double score,
  }) {
    return _repository.sendAlertFeedback(
      alertId: alertId,
      commentary: commentary,
      score: score,
    );
  }
}
