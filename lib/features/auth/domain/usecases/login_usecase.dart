import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, ({String token, String refreshToken, UserEntity user})>>
      call({required String email, required String password}) {
    return _repository.login(email: email, password: password);
  }
}
