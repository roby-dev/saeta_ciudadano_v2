import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/utils/alerts_summary.dart';

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
  group('computeAlertsSummary', () {
    test('returns all zeros for an empty list', () {
      final summary = computeAlertsSummary(const []);
      expect(summary.total, 0);
      expect(summary.active, 0);
      expect(summary.resolved, 0);
    });

    test('total counts every alert; active counts pending + in-process; '
        'resolved counts only resolved (cancelled/unknown excluded from '
        'both)', () {
      final alerts = [
        _alert('1', 'Pendiente'),
        _alert('2', 'En Proceso'),
        _alert('3', 'Resuelta'),
        _alert('4', 'Cancelada'),
        _alert('5', 'Algo Raro'),
      ];

      final summary = computeAlertsSummary(alerts);

      expect(summary.total, 5);
      expect(summary.active, 2);
      expect(summary.resolved, 1);
    });
  });
}
