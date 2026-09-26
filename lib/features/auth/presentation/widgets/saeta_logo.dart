import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

enum _SaetaLogoVariant { wordmark, brandMark }

/// SAETA wordmark, reused across the app rather than duplicated per screen.
///
/// Two looks, picked via the constructor used:
/// - [SaetaLogo.new] (the original): a plain "SAETA" wordmark sized by
///   [height] — used on the splash screen.
/// - [SaetaLogo.brandMark]: the auth screens' blue-band brand mark — a
///   white icon tile, the wordmark in white, and an optional [subtitle].
class SaetaLogo extends StatelessWidget {
  const SaetaLogo({super.key, this.height = 90})
      : subtitle = null,
        _variant = _SaetaLogoVariant.wordmark;

  const SaetaLogo.brandMark({super.key, this.subtitle})
      : height = 0,
        _variant = _SaetaLogoVariant.brandMark;

  /// Only used by the [SaetaLogo.new] (wordmark) variant.
  final double height;

  /// Only used by the [SaetaLogo.brandMark] variant. Shown below the
  /// wordmark when non-null (e.g. "Ciudadano · Seguridad ciudadana").
  final String? subtitle;

  final _SaetaLogoVariant _variant;

  @override
  Widget build(BuildContext context) {
    if (_variant == _SaetaLogoVariant.brandMark) {
      final subtitle = this.subtitle;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'SAETA',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.92,
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w300,
                color: AppColors.onPrimaryMuted,
              ),
            ),
          ],
        ],
      );
    }

    // Original plain wordmark, used on the splash screen.
    return SizedBox(
      height: height,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'SAETA',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
          ),
        ),
      ),
    );
  }
}
