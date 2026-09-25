import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/alert_type_entity.dart';
import '../repositories/emergency_repository.dart';

class GetAlertTypesUseCase {
  const GetAlertTypesUseCase(this._repository);

  final EmergencyRepository _repository;

  Future<Either<Failure, List<AlertTypeEntity>>> call() {
    return _repository.getAlertTypes();
  }
}
