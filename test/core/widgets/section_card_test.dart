import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/widgets/section_card.dart';

void main() {
  group('SectionCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(child: Text('Contenido')),
          ),
        ),
      );

      expect(find.text('Contenido'), findsOneWidget);
    });

    testWidgets('renders an optional title and trailing action',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionCard(
              title: 'Mis alertas',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Ver todo'),
              ),
              child: const Text('Contenido'),
            ),
          ),
        ),
      );

      expect(find.text('Mis alertas'), findsOneWidget);
      expect(find.text('Ver todo'), findsOneWidget);
    });

    testWidgets('omits the title row when no title is given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(child: Text('Contenido')),
          ),
        ),
      );

      expect(find.text('Mis alertas'), findsNothing);
    });
  });
}
