import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/utils/alert_timeline.dart';

const _base = CitizenAlertEntity(
  id: 'a1',
  userId: 'u1',
  latitude: 0,
  longitude: 0,
  typeName: 'Robo',
  stateName: 'Pendiente',
  creationDate: '2026-01-01T00:00:00.000Z',
);

void main() {
  group('alertTimelineSteps', () {
    test('a pending alert: only "Reportada" is completed, the other two '
        'are pending with no date and not emerald', () {
      final steps = alertTimelineSteps(_base);

      expect(steps, hasLength(3));
      expect(steps[0].label, 'Reportada');
      expect(steps[0].completed, isTrue);
      expect(steps[0].dateText, isNotNull);
      expect(steps[0].emerald, isFalse);

      expect(steps[1].label, 'En atención');
      expect(steps[1].completed, isFalse);
      expect(steps[1].dateText, isNull);

      expect(steps[2].label, 'Resuelta');
      expect(steps[2].completed, isFalse);
      expect(steps[2].dateText, isNull);
      expect(steps[2].emerald, isFalse);
    });

    test('an in-process alert with an attentionDate completes the second '
        'step but not the third', () {
      const alert = CitizenAlertEntity(
        id: 'a1',
        userId: 'u1',
        latitude: 0,
        longitude: 0,
        typeName: 'Robo',
        stateName: 'En Proceso',
        creationDate: '2026-01-01T00:00:00.000Z',
        attentionDate: '2026-01-02T00:00:00.000Z',
      );

      final steps = alertTimelineSteps(alert);

      expect(steps[1].completed, isTrue);
      expect(steps[1].dateText, '2026-01-02T00:00:00.000Z');
      expect(steps[2].completed, isFalse);
    });

    test('a resolved alert with a culminationDate labels the final step '
        '"Resuelta", completes it and marks it emerald', () {
      const alert = CitizenAlertEntity(
        id: 'a1',
        userId: 'u1',
        latitude: 0,
        longitude: 0,
        typeName: 'Robo',
        stateName: 'Resuelta',
        creationDate: '2026-01-01T00:00:00.000Z',
        attentionDate: '2026-01-02T00:00:00.000Z',
        culminationDate: '2026-01-03T00:00:00.000Z',
      );

      final steps = alertTimelineSteps(alert);

      expect(steps[2].label, 'Resuelta');
      expect(steps[2].completed, isTrue);
      expect(steps[2].dateText, '2026-01-03T00:00:00.000Z');
      expect(steps[2].emerald, isTrue);
    });

    test('a cancelled alert with a culminationDate labels the final step '
        '"Cancelada", completes it and marks it emerald', () {
      const alert = CitizenAlertEntity(
        id: 'a1',
        userId: 'u1',
        latitude: 0,
        longitude: 0,
        typeName: 'Robo',
        stateName: 'Cancelada',
        creationDate: '2026-01-01T00:00:00.000Z',
        culminationDate: '2026-01-03T00:00:00.000Z',
      );

      final steps = alertTimelineSteps(alert);

      expect(steps[2].label, 'Cancelada');
      expect(steps[2].completed, isTrue);
      expect(steps[2].emerald, isTrue);
    });
  });
}
