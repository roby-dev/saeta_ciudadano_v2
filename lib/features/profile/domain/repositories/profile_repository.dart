import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract interface class ProfileRepository {
  /// Updates the current user's own editable profile fields (name, lastname,
  /// phone, email) via `PATCH /v1/users/:id`. DNI, role and statusAccount are
  /// never sent — DNI is read-only for the citizen, and role/statusAccount
  /// changes are out of scope for self-service profile editing.
  Future<Either<Failure, UserEntity>> updateProfile({
    required String userId,
    required String name,
    required String lastname,
    required String phone,
    required String email,
  });
}
