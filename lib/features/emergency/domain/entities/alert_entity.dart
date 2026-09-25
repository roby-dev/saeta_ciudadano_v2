import 'package:equatable/equatable.dart';

class AlertEntity extends Equatable {
  const AlertEntity({
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

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        typeId,
        stateId,
        creationDate,
      ];
}
