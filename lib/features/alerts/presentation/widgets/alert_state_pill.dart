import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Small pill (colored dot + label) showing a raw Spanish alert
/// `stateName`.
///
/// Maps `stateName` to one of the 4 [AppColors] state palettes using the
/// same case-insensitive substring convention as
/// `CitizenAlertEntity.isResolved`/`isInProcess`/`isPending`/`isCancelled`
/// and `alertMarkerHue`; an unmatched state falls back to
/// [AppColors.neutral].
class AlertStatePill extends StatelessWidget {
  const AlertStatePill({super.key, required this.stateName});

  final String stateName;

  /// Exposed for reuse (e.g. tinting an icon/marker to match the pill)
  /// and direct unit testing of the state->palette mapping.
  static AlertStatePalette paletteFor(String stateName) {
    final normalized = stateName.toLowerCase();
    if (normalized.contains('resuelta')) return AppColors.resuelta;
    if (normalized.contains('proceso')) return AppColors.enProceso;
    if (normalized.contains('pendiente')) return AppColors.pendiente;
    if (normalized.contains('cancel')) return AppColors.cancelada;
    return AppColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteFor(stateName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('alert-state-pill-dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: palette.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            stateName,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
