import 'package:equatable/equatable.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

final class RegisterDniChanged extends RegisterEvent {
  const RegisterDniChanged(this.dni);
  final String dni;
  @override
  List<Object?> get props => [dni];
}

final class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({
    required this.dni,
    required this.name,
    required this.lastname,
    required this.phone,
    required this.email,
    required this.password,
  });

  final String dni;
  final String name;
  final String lastname;
  final String phone;
  final String email;
  final String password;

  @override
  List<Object?> get props =>
      [dni, name, lastname, phone, email, password];
}
