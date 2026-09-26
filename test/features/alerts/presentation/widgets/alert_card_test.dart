import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/widgets/alert_card.dart';

const _alert = CitizenAlertEntity(
  id: 'a1',
  userId: 'u1',
  latitude: -12.0,
  longitude: -77.0,
  typeName: 'Robo',
  stateName: 'Pendiente',
  creationDate: '2026-09-26T14:32:00.000Z',
);

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onTap,
  bool historical = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AlertCard(
          alert: _alert,
          onTap: onTap,
          historical: historical,
        ),
      ),
    ),
  );
}

void main() {
  group('AlertCard', () {
    testWidgets('shows the type name, formatted date and state pill',
        (tester) async {
      await _pump(tester, onTap: () {});

      expect(find.text('Robo'), findsOneWidget);
      expect(find.text('26 sep 2026 · 14:32'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
    });

    testWidgets('tapping the card invokes onTap', (tester) async {
      var tapped = false;
      await _pump(tester, onTap: () => tapped = true);

      await tester.tap(find.byType(AlertCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('the type icon tile uses the primary tint by default '
        '(active)', (tester) async {
      await _pump(tester, onTap: () {});

      final tile = tester.widget<Container>(
        find.byKey(const ValueKey('alert-card-type-tile')),
      );
      final decoration = tile.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.primaryTint);
    });

    testWidgets('the type icon tile uses the slate palette when historical',
        (tester) async {
      await _pump(tester, onTap: () {}, historical: true);

      final tile = tester.widget<Container>(
        find.byKey(const ValueKey('alert-card-type-tile')),
      );
      final decoration = tile.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.neutral.background);
    });
  });
}
