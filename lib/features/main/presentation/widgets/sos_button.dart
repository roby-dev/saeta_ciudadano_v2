import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// The SOS circle on [EmergencyView]'s hero card: an outer 168px
/// [AppColors.dangerTint] ring around an inner 136px [AppColors.danger]
/// circle showing "SOS" + [label].
class SosButton extends StatelessWidget {
  const SosButton({
    super.key,
    required this.onPressed,
    this.label = 'EMERGENCIA',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.dangerTint,
      ),
      child: Material(
        shape: const CircleBorder(),
        color: AppColors.danger,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 136,
            height: 136,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SOS',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
