import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/person_entity.dart';
import '../repositories/register_repository.dart';

class LookupDniUseCase {
  const LookupDniUseCase(this._repository);

  final RegisterRepository _repository;

  Future<Either<Failure, PersonEntity>> call(String dni) {
    return _repository.lookupDni(dni);
  }
}
