import '../../domain/entities/alert_entity.dart';

class AlertModel {
  const AlertModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.typeId,
    required this.stateId,
    required this.creationDate,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String typeId;
  final String stateId;
  final String creationDate;

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    // Backend can return `type` or `typeId`, and `state` or `stateId`
    final typeVal = json['typeId'] ?? json['type'];
    final stateVal = json['stateId'] ?? json['state'];

    final typeId = typeVal is Map ? (typeVal['id'] ?? typeVal['_id'] ?? '') : (typeVal?.toString() ?? '');
    final stateId = stateVal is Map ? (stateVal['id'] ?? stateVal['_id'] ?? '') : (stateVal?.toString() ?? '');

    return AlertModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      typeId: typeId,
      stateId: stateId,
      creationDate: json['creationDate'] as String? ?? '',
    );
  }

  AlertEntity toEntity() {
    return AlertEntity(
      id: id,
      latitude: latitude,
      longitude: longitude,
      typeId: typeId,
      stateId: stateId,
      creationDate: creationDate,
    );
  }
}
