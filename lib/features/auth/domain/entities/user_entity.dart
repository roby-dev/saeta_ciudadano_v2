import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String lastname;
  final String dni;
  final String phone;
  final String email;
  final String image;
  final String role;
  final String stateAccount;
  final double averageScore;
  final int alertsAttended;

  const UserEntity({
    required this.id,
    required this.name,
    required this.lastname,
    required this.dni,
    required this.phone,
    required this.email,
    required this.image,
    required this.role,
    required this.stateAccount,
    required this.averageScore,
    required this.alertsAttended,
  });

  String get fullName => '$name $lastname';

  @override
  List<Object?> get props => [
        id, name, lastname, dni, phone, email,
        image, role, stateAccount, averageScore, alertsAttended,
      ];
}
