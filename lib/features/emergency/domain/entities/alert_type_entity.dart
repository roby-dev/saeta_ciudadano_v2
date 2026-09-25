import 'package:equatable/equatable.dart';

class AlertTypeEntity extends Equatable {
  const AlertTypeEntity({
    required this.id,
    required this.name,
    this.priority,
  });

  final String id;
  final String name;
  final int? priority;

  @override
  List<Object?> get props => [id, name, priority];
}
