import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/widgets/saeta_logo.dart';

void main() {
  group('SaetaLogo (wordmark)', () {
    testWidgets('renders only the SAETA wordmark, no icon tile', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SaetaLogo(height: 90))),
      );

      expect(find.text('SAETA'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
    });
  });

  group('SaetaLogo.brandMark', () {
    testWidgets('renders the icon tile, wordmark and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SaetaLogo.brandMark(
              subtitle: 'Ciudadano · Seguridad ciudadana',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text('SAETA'), findsOneWidget);
      expect(find.text('Ciudadano · Seguridad ciudadana'), findsOneWidget);

      final titleStyle = tester.widget<Text>(find.text('SAETA')).style;
      expect(titleStyle?.color, Colors.white);
      expect(titleStyle?.fontWeight, FontWeight.bold);

      final subtitleStyle = tester
          .widget<Text>(find.text('Ciudadano · Seguridad ciudadana'))
          .style;
      expect(subtitleStyle?.color, AppColors.onPrimaryMuted);
    });

    testWidgets('omits the subtitle text when none is given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SaetaLogo.brandMark()),
        ),
      );

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.text('SAETA'), findsOneWidget);
    });
  });
}
