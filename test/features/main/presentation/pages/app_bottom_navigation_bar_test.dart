import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/pages/main_page.dart';

void main() {
  group('AppBottomNavigationBar', () {
    testWidgets('shows the 3 Spanish labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigationBar(
              currentIndex: 0,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Emergencia'), findsOneWidget);
      expect(find.text('Alertas'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
    });

    testWidgets('marks the active item in primary color and semibold',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigationBar(
              currentIndex: 1,
              onDestinationSelected: (_) {},
            ),
          ),
        ),
      );

      final activeLabel = tester.widget<Text>(find.text('Alertas'));
      expect(activeLabel.style?.color, AppColors.primary);
      expect(activeLabel.style?.fontWeight, FontWeight.w600);

      final inactiveLabel = tester.widget<Text>(find.text('Emergencia'));
      expect(inactiveLabel.style?.color, AppColors.muted);
      expect(inactiveLabel.style?.fontWeight, isNot(FontWeight.w600));
    });

    testWidgets('tapping an item reports its index', (tester) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigationBar(
              currentIndex: 0,
              onDestinationSelected: (index) => tapped = index,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Perfil'));
      await tester.pump();

      expect(tapped, 2);
    });
  });
}
