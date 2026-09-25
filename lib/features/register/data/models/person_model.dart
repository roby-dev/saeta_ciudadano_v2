import '../../domain/entities/person_entity.dart';

class PersonModel {
  const PersonModel({
    required this.nombres,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
  });

  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    return PersonModel(
      nombres: json['nombres'] as String? ?? '',
      apellidoPaterno: json['apellidoPaterno'] as String? ?? '',
      apellidoMaterno: json['apellidoMaterno'] as String? ?? '',
    );
  }

  PersonEntity toEntity() {
    final names = _toTitleCase(nombres);
    final lastname = _toTitleCase(
        [apellidoPaterno, apellidoMaterno]
            .where((s) => s.isNotEmpty)
            .join(' '));
    return PersonEntity(names: names, lastname: lastname);
  }

  static String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(' ')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
