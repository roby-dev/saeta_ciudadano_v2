import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/user_entity.dart';

sealed class RegisterState extends Equatable {
  const RegisterState();

  @override
  List<Object?> get props => [];
}

final class RegisterInitial extends RegisterState {
  const RegisterInitial();
}

/// Fired while the RENIEC DNI lookup is in flight.
final class RegisterDniLookingUp extends RegisterState {
  const RegisterDniLookingUp();
}

/// DNI lookup succeeded — carries auto-filled name + lastname.
final class RegisterDniFound extends RegisterState {
  const RegisterDniFound({required this.names, required this.lastname});
  final String names;
  final String lastname;
  @override
  List<Object?> get props => [names, lastname];
}

/// DNI lookup failed — show error but keep form editable.
final class RegisterDniNotFound extends RegisterState {
  const RegisterDniNotFound(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Full registration call is in flight.
final class RegisterLoading extends RegisterState {
  const RegisterLoading();
}

/// Registration succeeded.
final class RegisterSuccess extends RegisterState {
  const RegisterSuccess({required this.user, required this.token});
  final UserEntity user;
  final String token;
  @override
  List<Object?> get props => [user, token];
}

/// Registration failed.
final class RegisterFailure extends RegisterState {
  const RegisterFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
