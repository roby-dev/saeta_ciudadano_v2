import 'package:equatable/equatable.dart';
import '../../domain/entities/emergency_contact_entity.dart';

class EmergencyContactModel extends Equatable {
  const EmergencyContactModel({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }

  factory EmergencyContactModel.fromEntity(EmergencyContactEntity entity) {
    return EmergencyContactModel(name: entity.name, phone: entity.phone);
  }

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  EmergencyContactEntity toEntity() =>
      EmergencyContactEntity(name: name, phone: phone);

  @override
  List<Object?> get props => [name, phone];
}
