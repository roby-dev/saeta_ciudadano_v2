import 'package:flutter/material.dart';

/// Icon for an alert's `typeName`, shared by [AlertCard] and
/// `AlertDetailSheet`'s summary card so both use the exact same mapping.
IconData alertTypeIcon(String typeName) {
  final lower = typeName.toLowerCase();
  if (lower.contains('robo')) return Icons.local_police_outlined;
  if (lower.contains('incendio')) return Icons.local_fire_department_outlined;
  if (lower.contains('violencia')) return Icons.family_restroom_outlined;
  if (lower.contains('accidente')) return Icons.car_crash_outlined;
  if (lower.contains('pandillaje')) return Icons.groups_outlined;
  return Icons.warning_amber_rounded;
}
