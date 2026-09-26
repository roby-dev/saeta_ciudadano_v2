import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/widgets/saeta_text_field.dart';

void main() {
  group('SaetaTextField', () {
    testWidgets(
        'shows the label above the input, not as a Material floating label',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SaetaTextField(label: 'Correo electrónico')),
        ),
      );

      expect(find.text('Correo electrónico'), findsOneWidget);
      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration;
      expect(decoration?.labelText, isNull);
    });

    testWidgets('toggles obscured text via the eye icon for password fields',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SaetaTextField(label: 'Contraseña', obscureText: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isFalse);
    });

    testWidgets('reports text changes via onChanged', (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaetaTextField(label: 'DNI', onChanged: (v) => changed = v),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '12345678');
      expect(changed, '12345678');
    });

    testWidgets('omits the prefix icon when none is given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SaetaTextField(label: 'Nombre')),
        ),
      );

      final decoration =
          tester.widget<TextField>(find.byType(TextField)).decoration;
      expect(decoration?.prefixIcon, isNull);
    });
  });
}
