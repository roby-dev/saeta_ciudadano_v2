import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthLoginSubmitted extends AuthEvent {
  const AuthLoginSubmitted({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  final String email;
  final String password;
  final bool rememberMe;

  @override
  List<Object?> get props => [email, password, rememberMe];
}

final class AuthSessionChecked extends AuthEvent {
  const AuthSessionChecked();
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
