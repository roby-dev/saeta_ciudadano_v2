import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/widgets/alert_state_pill.dart';

void main() {
  group('AlertStatePill.paletteFor', () {
    // Same case-insensitive substring convention as
    // CitizenAlertEntity.isResolved/isInProcess/isPending/isCancelled and
    // alertMarkerHue.
    test('Resuelta maps to the resuelta palette', () {
      expect(AlertStatePill.paletteFor('Resuelta'), AppColors.resuelta);
    });

    test('En proceso maps to the enProceso palette', () {
      expect(AlertStatePill.paletteFor('En proceso'), AppColors.enProceso);
    });

    test('Pendiente maps to the pendiente palette', () {
      expect(AlertStatePill.paletteFor('Pendiente'), AppColors.pendiente);
    });

    test('Cancelada maps to the cancelada palette', () {
      expect(AlertStatePill.paletteFor('Cancelada'), AppColors.cancelada);
    });

    test('matching is case-insensitive', () {
      expect(AlertStatePill.paletteFor('RESUELTA'), AppColors.resuelta);
      expect(AlertStatePill.paletteFor('pendiente'), AppColors.pendiente);
    });

    test('an unknown state falls back to the neutral palette', () {
      expect(AlertStatePill.paletteFor('Desconocido'), AppColors.neutral);
      expect(AlertStatePill.paletteFor(''), AppColors.neutral);
    });
  });

  group('AlertStatePill widget', () {
    testWidgets('renders the raw state name as its label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AlertStatePill(stateName: 'Resuelta')),
        ),
      );

      expect(find.text('Resuelta'), findsOneWidget);
    });

    testWidgets('shows a status dot in the state\'s dot color',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AlertStatePill(stateName: 'Pendiente')),
        ),
      );

      final dotFinder = find.byKey(const ValueKey('alert-state-pill-dot'));
      expect(dotFinder, findsOneWidget);
      final decoratedBox = tester.widget<Container>(dotFinder);
      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.color, AppColors.pendiente.dot);
    });
  });
}
