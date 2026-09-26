import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/utils/alerts_grouping.dart';

CitizenAlertEntity _alert(String id, String stateName) => CitizenAlertEntity(
      id: id,
      userId: 'u1',
      latitude: 0,
      longitude: 0,
      typeName: 'Robo',
      stateName: stateName,
      creationDate: '2026-01-01T00:00:00.000Z',
    );

void main() {
  group('groupAlerts', () {
    test('returns empty active/history lists for an empty input', () {
      final grouped = groupAlerts(const []);
      expect(grouped.active, isEmpty);
      expect(grouped.history, isEmpty);
    });

    test('groups pending/in-process into active and resolved/cancelled/'
        'unknown into history, preserving relative order in each group',
        () {
      final pending = _alert('1', 'Pendiente');
      final resolved = _alert('2', 'Resuelta');
      final inProcess = _alert('3', 'En Proceso');
      final cancelled = _alert('4', 'Cancelada');
      final unknown = _alert('5', 'Algo Raro');

      final grouped = groupAlerts(
        [pending, resolved, inProcess, cancelled, unknown],
      );

      expect(grouped.active, [pending, inProcess]);
      expect(grouped.history, [resolved, cancelled, unknown]);
    });
  });
}
