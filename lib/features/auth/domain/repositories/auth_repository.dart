import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/user_entity.dart';

abstract interface class AuthRepository {
  Future<Either<Failure, ({String token, String refreshToken, UserEntity user})>>
      login({required String email, required String password});

  Future<Either<Failure, String>> renewToken(String refreshToken);
}
