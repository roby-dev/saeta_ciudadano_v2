import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    final theme = AppTheme.light;

    test('uses Material 3 with the canvas color scheme', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.colorScheme.error, AppColors.danger);
      expect(theme.colorScheme.surface, AppColors.surface);
    });

    test('scaffold background is the canvas background token', () {
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('the default text theme font family is IBM Plex Sans', () {
      expect(theme.textTheme.bodyMedium?.fontFamily, AppFonts.sans);
      expect(theme.textTheme.titleLarge?.fontFamily, AppFonts.sans);
    });

    test('headings use the heading color, semibold, 18-20', () {
      expect(theme.textTheme.titleLarge?.color, AppColors.heading);
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.titleLarge?.fontSize, inInclusiveRange(18, 20));
    });

    test('the app bar is a solid primary band with white text', () {
      expect(theme.appBarTheme.backgroundColor, AppColors.primary);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('filled buttons use the primary color, 48 height, 10 radius', () {
      final resolved = theme.filledButtonTheme.style!;
      final backgroundColor = resolved.backgroundColor
          ?.resolve(<WidgetState>{});
      final minimumSize = resolved.minimumSize?.resolve(<WidgetState>{});
      final shape = resolved.shape?.resolve(<WidgetState>{})
          as RoundedRectangleBorder?;
      expect(backgroundColor, AppColors.primary);
      expect(minimumSize?.height, 48);
      expect(
        (shape?.borderRadius as BorderRadius?)?.topLeft.x,
        10,
      );
    });

    test('outlined (secondary) buttons use the CBD5E1 border', () {
      final resolved = theme.outlinedButtonTheme.style!;
      final side = resolved.side?.resolve(<WidgetState>{});
      expect(side?.color, AppColors.secondaryBorder);
    });

    test('inputs are 10-radius bordered fields', () {
      final border = theme.inputDecorationTheme.border as OutlineInputBorder?;
      expect(border?.borderRadius, BorderRadius.circular(10));
    });

    test('cards are white, 12 radius, 1px E2E8F0 border', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(theme.cardTheme.color, AppColors.surface);
      expect((shape?.borderRadius as BorderRadius?)?.topLeft.x, 12);
      expect(shape?.side.color, AppColors.border);
      expect(shape?.side.width, 1);
    });

    test('bottom navigation is white with the E2E8F0 top border color '
        'available for a custom indicator', () {
      expect(theme.navigationBarTheme.backgroundColor, AppColors.surface);
    });
  });

  group('AppTheme.light button sizing', () {
    // Regression: a theme-level `minimumSize` with infinite width made any
    // button placed inside a Row (e.g. a SectionCard trailing action) throw
    // "BoxConstraints forces an infinite width" on device.
    testWidgets('every button type lays out inside a Row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                TextButton(onPressed: () {}, child: const Text('Text')),
                OutlinedButton(onPressed: () {}, child: const Text('Out')),
                FilledButton(onPressed: () {}, child: const Text('Fill')),
                ElevatedButton(onPressed: () {}, child: const Text('Elev')),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final height = tester.getSize(find.byType(TextButton)).height;
      expect(height, greaterThanOrEqualTo(AppDimens.controlHeight));
    });
  });
}
