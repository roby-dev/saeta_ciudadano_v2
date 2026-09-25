import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/emergency_contact_entity.dart';
import '../repositories/emergency_contacts_repository.dart';

class SaveEmergencyContactsUseCase {
  const SaveEmergencyContactsUseCase(this._repository);

  final EmergencyContactsRepository _repository;

  Future<Either<Failure, List<EmergencyContactEntity>>> call(
    String userId,
    List<EmergencyContactEntity> contacts,
  ) {
    return _repository.saveContacts(userId, contacts);
  }
}
