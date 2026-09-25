import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/emergency_contact_entity.dart';
import '../repositories/emergency_contacts_repository.dart';

class GetEmergencyContactsUseCase {
  const GetEmergencyContactsUseCase(this._repository);

  final EmergencyContactsRepository _repository;

  Future<Either<Failure, List<EmergencyContactEntity>>> call(String userId) {
    return _repository.getContacts(userId);
  }
}
