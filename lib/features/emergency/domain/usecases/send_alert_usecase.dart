import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/alert_entity.dart';
import '../repositories/emergency_repository.dart';

class SendAlertUseCase {
  const SendAlertUseCase(this._repository);

  final EmergencyRepository _repository;

  Future<Either<Failure, AlertEntity>> call({
    required double latitude,
    required double longitude,
    required String typeId,
  }) {
    return _repository.sendAlert(
      latitude: latitude,
      longitude: longitude,
      typeId: typeId,
    );
  }
}
