import 'package:equatable/equatable.dart';

class EmergencyContactEntity extends Equatable {
  const EmergencyContactEntity({
    required this.name,
    required this.phone,
  });

  final String name;

  /// Always the normalized 9-digit Peruvian phone number.
  final String phone;

  @override
  List<Object?> get props => [name, phone];
}
