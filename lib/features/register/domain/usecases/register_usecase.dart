import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../repositories/register_repository.dart';

class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final RegisterRepository _repository;

  Future<Either<Failure, ({String token, String refreshToken, UserEntity user})>>
      call({
    required String dni,
    required String name,
    required String lastname,
    required String phone,
    required String email,
    required String password,
  }) {
    return _repository.register(
      dni: dni,
      name: name,
      lastname: lastname,
      phone: phone,
      email: email,
      password: password,
    );
  }
}
