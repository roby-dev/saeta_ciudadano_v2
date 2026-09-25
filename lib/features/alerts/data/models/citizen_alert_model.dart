import '../../domain/entities/citizen_alert_entity.dart';

class CitizenAlertModel {
  const CitizenAlertModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.typeName,
    required this.stateName,
    required this.creationDate,
    this.attentionDate,
    this.culminationDate,
    this.attendedByName,
    this.attendedByPhone,
    this.commentary,
    this.score,
  });

  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final String typeName;
  final String stateName;
  final String creationDate;
  final String? attentionDate;
  final String? culminationDate;
  final String? attendedByName;
  final String? attendedByPhone;
  final String? commentary;
  final double? score;

  factory CitizenAlertModel.fromJson(Map<String, dynamic> json) {
    // Extract type name from populated object or fallback string
    String resolvedTypeName = 'Emergencia';
    final typeVal = json['type'] ?? json['typeId'];
    if (typeVal is Map<String, dynamic>) {
      resolvedTypeName = typeVal['name'] as String? ?? 'Emergencia';
    } else if (typeVal is String && typeVal.isNotEmpty) {
      resolvedTypeName = typeVal;
    }

    // Extract state name from populated object or fallback string
    String resolvedStateName = 'Pendiente';
    final stateVal = json['state'] ?? json['stateId'];
    if (stateVal is Map<String, dynamic>) {
      resolvedStateName = stateVal['name'] as String? ?? 'Pendiente';
    } else if (stateVal is String && stateVal.isNotEmpty) {
      resolvedStateName = stateVal;
    }

    // Extract attendedBy user info if present
    String? attendedByName;
    String? attendedByPhone;
    final attendedVal = json['attendedBy'] ?? json['attendedById'];
    if (attendedVal is Map<String, dynamic>) {
      final name = attendedVal['name'] as String? ?? '';
      final lastname = attendedVal['lastname'] as String? ?? '';
      final fullName = '$name $lastname'.trim();
      attendedByName = fullName.isNotEmpty ? fullName : null;
      attendedByPhone = attendedVal['phone'] as String?;
    }

    // Handle user field (can be object or string id)
    final userVal = json['user'] ?? json['userId'];
    final resolvedUserId = userVal is Map<String, dynamic>
        ? (userVal['id'] ?? userVal['_id'] ?? '').toString()
        : (userVal?.toString() ?? '');

    return CitizenAlertModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      userId: resolvedUserId,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      typeName: resolvedTypeName,
      stateName: resolvedStateName,
      creationDate: json['creationDate'] as String? ?? '',
      attentionDate: json['attentionDate'] as String?,
      culminationDate: json['culminationDate'] as String?,
      attendedByName: attendedByName,
      attendedByPhone: attendedByPhone,
      commentary: json['commentary'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  CitizenAlertEntity toEntity() {
    return CitizenAlertEntity(
      id: id,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      typeName: typeName,
      stateName: stateName,
      creationDate: creationDate,
      attentionDate: attentionDate,
      culminationDate: culminationDate,
      attendedByName: attendedByName,
      attendedByPhone: attendedByPhone,
      commentary: commentary,
      score: score,
    );
  }
}
