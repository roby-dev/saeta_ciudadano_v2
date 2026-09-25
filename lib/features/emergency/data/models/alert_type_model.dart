import '../../domain/entities/alert_type_entity.dart';

class AlertTypeModel {
  const AlertTypeModel({
    required this.id,
    required this.name,
    this.priority,
  });

  final String id;
  final String name;
  final int? priority;

  factory AlertTypeModel.fromJson(Map<String, dynamic> json) {
    return AlertTypeModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priority: json['priority'] as int?,
    );
  }

  AlertTypeEntity toEntity() {
    return AlertTypeEntity(
      id: id,
      name: name,
      priority: priority,
    );
  }
}
