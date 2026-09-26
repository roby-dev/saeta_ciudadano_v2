import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Validates the stored session against the backend (`GET /v1/auth/me`),
/// used by `AuthBloc` to auto-login on app start.
class GetCurrentUserUseCase {
  const GetCurrentUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserEntity>> call() => _repository.getCurrentUser();
}
