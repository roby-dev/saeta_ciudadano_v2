import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/widgets/alert_map_card.dart';

void main() {
  group('AlertMapCard placeholder path', () {
    // (0, 0) is the missing-coordinate sentinel (see alertMapCoordinates) -
    // the map itself is never built, so this is the one path testable
    // without a real GoogleMap platform view.
    testWidgets('zero coordinates show the placeholder, not a map', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlertMapCard(
              latitude: 0,
              longitude: 0,
              stateName: 'Pendiente',
              typeName: 'Robo',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ubicación no disponible'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
      expect(find.text('Abrir en Google Maps'), findsNothing);
    });

    testWidgets('invalid (out-of-range) coordinates show the placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlertMapCard(
              latitude: 91,
              longitude: -77.0428,
              stateName: 'Cancelada',
              typeName: 'Incendio',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ubicación no disponible'), findsOneWidget);
      expect(find.text('Abrir en Google Maps'), findsNothing);
    });
  });
}
