import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, UserEntity>> call(
    String userId, {
    required String name,
    required String lastname,
    required String phone,
    required String email,
  }) {
    return _repository.updateProfile(
      userId: userId,
      name: name,
      lastname: lastname,
      phone: phone,
      email: email,
    );
  }
}
