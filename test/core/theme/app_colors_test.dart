import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    // Design tokens from the approved redesign canvas ("Frontend v2
    // palette, pro look"), see odd/tasks/ui-redesign.md.
    test('core brand and surface tokens match the canvas hex values', () {
      expect(AppColors.primary, const Color(0xFF1976D2));
      expect(AppColors.primaryDark, const Color(0xFF1565C0));
      expect(AppColors.primaryTint, const Color(0xFFE8F1FB));
      expect(AppColors.heading, const Color(0xFF2B354F));
      expect(AppColors.text, const Color(0xFF334155));
      expect(AppColors.muted, const Color(0xFF64748B));
      expect(AppColors.border, const Color(0xFFE2E8F0));
      expect(AppColors.background, const Color(0xFFF4F6F9));
      expect(AppColors.surface, const Color(0xFFFFFFFF));
      expect(AppColors.secondaryBorder, const Color(0xFFCBD5E1));
    });

    test('danger tokens match the canvas hex values', () {
      expect(AppColors.danger, const Color(0xFFE11D48));
      expect(AppColors.dangerTint, const Color(0xFFFFE4E6));
      expect(AppColors.dangerTintAlt, const Color(0xFFFFF1F2));
    });

    test('the 4 alert state palettes (bg/border/text/dot) match the canvas',
        () {
      expect(
        AppColors.pendiente,
        const AlertStatePalette(
          background: Color(0xFFFFFBEB),
          border: Color(0xFFFDE68A),
          text: Color(0xFFB45309),
          dot: Color(0xFFF59E0B),
        ),
      );
      expect(
        AppColors.enProceso,
        const AlertStatePalette(
          background: Color(0xFFF0F9FF),
          border: Color(0xFFBAE6FD),
          text: Color(0xFF0369A1),
          dot: Color(0xFF0EA5E9),
        ),
      );
      expect(
        AppColors.resuelta,
        const AlertStatePalette(
          background: Color(0xFFECFDF5),
          border: Color(0xFFA7F3D0),
          text: Color(0xFF047857),
          dot: Color(0xFF10B981),
        ),
      );
      expect(
        AppColors.cancelada,
        const AlertStatePalette(
          background: Color(0xFFFFF1F2),
          border: Color(0xFFFECDD3),
          text: Color(0xFFBE123C),
          dot: Color(0xFFF43F5E),
        ),
      );
    });

    test('liveDot (Mis alertas header "live" indicator) matches the canvas',
        () {
      expect(AppColors.liveDot, const Color(0xFF34D399));
    });

    test('the neutral/unknown-state palette is a distinct slate style', () {
      const neutral = AppColors.neutral;
      expect(neutral, isNot(AppColors.pendiente));
      expect(neutral, isNot(AppColors.enProceso));
      expect(neutral, isNot(AppColors.resuelta));
      expect(neutral, isNot(AppColors.cancelada));
    });
  });
}
