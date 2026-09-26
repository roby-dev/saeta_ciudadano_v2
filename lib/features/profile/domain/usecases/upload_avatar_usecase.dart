import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/profile_repository.dart';

class UploadAvatarUseCase {
  const UploadAvatarUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, UserEntity>> call(
    String userId, {
    required String filePath,
  }) {
    return _repository.uploadAvatar(userId: userId, filePath: filePath);
  }
}
