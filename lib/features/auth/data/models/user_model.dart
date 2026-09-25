import '../../domain/entities/user_entity.dart';

class UserModel {
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

  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
      dni: json['dni'] as String? ?? json['DNI'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      image: json['image'] as String? ?? '',
      role: json['role'] as String? ?? '',
      stateAccount: json['statusAccount'] as String? ??
          json['stateAccount'] as String? ??
          '',
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      alertsAttended: json['alertsAttended'] as int? ?? 0,
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      lastname: lastname,
      dni: dni,
      phone: phone,
      email: email,
      image: image,
      role: role,
      stateAccount: stateAccount,
      averageScore: averageScore,
      alertsAttended: alertsAttended,
    );
  }
}
