import 'package:equatable/equatable.dart';

class CitizenAlertEntity extends Equatable {
  const CitizenAlertEntity({
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

  bool get isResolved => stateName.toLowerCase().contains('resuelta');
  bool get isInProcess => stateName.toLowerCase().contains('proceso');
  bool get isPending => stateName.toLowerCase().contains('pendiente');
  bool get isCancelled => stateName.toLowerCase().contains('cancel');

  CitizenAlertEntity copyWith({
    String? commentary,
    double? score,
  }) {
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
      commentary: commentary ?? this.commentary,
      score: score ?? this.score,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        latitude,
        longitude,
        typeName,
        stateName,
        creationDate,
        attentionDate,
        culminationDate,
        attendedByName,
        attendedByPhone,
        commentary,
        score,
      ];
}
