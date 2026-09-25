import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/alert_entity.dart';
import '../entities/alert_type_entity.dart';

abstract interface class EmergencyRepository {
  Future<Either<Failure, List<AlertTypeEntity>>> getAlertTypes();

  Future<Either<Failure, AlertEntity>> sendAlert({
    required double latitude,
    required double longitude,
    required String typeId,
  });
}
