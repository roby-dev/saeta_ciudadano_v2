import 'package:flutter/material.dart';

enum _SaetaButtonVariant { primary, outlined }

class SaetaButton extends StatelessWidget {
  const SaetaButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : _variant = _SaetaButtonVariant.primary;

  const SaetaButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : _variant = _SaetaButtonVariant.outlined;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final _SaetaButtonVariant _variant;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    return SizedBox(
      width: double.infinity,
      child: switch (_variant) {
        _SaetaButtonVariant.primary => FilledButton(
            onPressed: isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: child,
            ),
          ),
        _SaetaButtonVariant.outlined => OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: child,
            ),
          ),
      },
    );
  }
}
