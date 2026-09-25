import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../entities/person_entity.dart';

abstract interface class RegisterRepository {
  Future<Either<Failure, PersonEntity>> lookupDni(String dni);

  Future<Either<Failure, ({String token, String refreshToken, UserEntity user})>>
      register({
    required String dni,
    required String name,
    required String lastname,
    required String phone,
    required String email,
    required String password,
  });
}
