import 'package:equatable/equatable.dart';

class PersonEntity extends Equatable {
  const PersonEntity({
    required this.names,
    required this.lastname,
  });

  final String names;
  final String lastname;

  @override
  List<Object?> get props => [names, lastname];
}
