import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/emergency_contact_entity.dart';

abstract interface class EmergencyContactsRepository {
  Future<Either<Failure, List<EmergencyContactEntity>>> getContacts(
    String userId,
  );

  Future<Either<Failure, List<EmergencyContactEntity>>> saveContacts(
    String userId,
    List<EmergencyContactEntity> contacts,
  );
}
