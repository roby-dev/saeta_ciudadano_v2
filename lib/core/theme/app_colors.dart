import 'package:flutter/material.dart';

/// Color design tokens for the approved redesign canvas ("Frontend v2
/// palette, pro look"), shared by [AppTheme] and presentation widgets.
///
/// See `odd/tasks/ui-redesign.md` ("Design tokens (from saeta-frontend-v2)")
/// for the source of truth; these are the exact hex values from that
/// document, not derived/generated shades.
class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryTint = Color(0xFFE8F1FB);

  // Text / surfaces
  static const Color heading = Color(0xFF2B354F);
  static const Color text = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);

  /// Border for outlined ("secondary") buttons/controls.
  static const Color secondaryBorder = Color(0xFFCBD5E1);

  /// Light blue-white text/subtitle on top of [primary]/[primaryDark]
  /// backgrounds (auth header band, emergency header band).
  static const Color onPrimaryMuted = Color(0xFFD6E6F7);

  /// Small "live" status dot (Mis alertas header subtitle "Actualización en
  /// tiempo real") — a distinct emerald-400, not the [resuelta] state's
  /// emerald-500 [AlertStatePalette.dot].
  static const Color liveDot = Color(0xFF34D399);

  // Danger (SOS / send alert)
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerTint = Color(0xFFFFE4E6);
  static const Color dangerTintAlt = Color(0xFFFFF1F2);

  // Alert state palettes (bg / border / text / dot)
  static const AlertStatePalette pendiente = AlertStatePalette(
    background: Color(0xFFFFFBEB),
    border: Color(0xFFFDE68A),
    text: Color(0xFFB45309),
    dot: Color(0xFFF59E0B),
  );

  static const AlertStatePalette enProceso = AlertStatePalette(
    background: Color(0xFFF0F9FF),
    border: Color(0xFFBAE6FD),
    text: Color(0xFF0369A1),
    dot: Color(0xFF0EA5E9),
  );

  static const AlertStatePalette resuelta = AlertStatePalette(
    background: Color(0xFFECFDF5),
    border: Color(0xFFA7F3D0),
    text: Color(0xFF047857),
    dot: Color(0xFF10B981),
  );

  static const AlertStatePalette cancelada = AlertStatePalette(
    background: Color(0xFFFFF1F2),
    border: Color(0xFFFECDD3),
    text: Color(0xFFBE123C),
    dot: Color(0xFFF43F5E),
  );

  /// Fallback for a `stateName` that doesn't match any of the 4 known
  /// states (see `alertMarkerHue`'s equivalent fallback). Not part of the
  /// canvas's explicit token list; a neutral slate style consistent with
  /// [muted]/[border].
  static const AlertStatePalette neutral = AlertStatePalette(
    background: Color(0xFFF1F5F9),
    border: Color(0xFFCBD5E1),
    text: Color(0xFF475569),
    dot: Color(0xFF94A3B8),
  );
}

/// One state's colors: chip/pill background, border, text and status dot.
@immutable
class AlertStatePalette {
  const AlertStatePalette({
    required this.background,
    required this.border,
    required this.text,
    required this.dot,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color dot;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertStatePalette &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          border == other.border &&
          text == other.text &&
          dot == other.dot;

  @override
  int get hashCode => Object.hash(background, border, text, dot);
}
