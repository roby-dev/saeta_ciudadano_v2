import 'package:flutter/material.dart';

class SaetaLogo extends StatelessWidget {
  const SaetaLogo({super.key, this.height = 90});

  final double height;

  @override
  Widget build(BuildContext context) {
    // Replace with Image.asset('assets/images/logo_saeta.png') once asset is added.
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
