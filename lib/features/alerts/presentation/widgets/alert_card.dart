import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/citizen_alert_entity.dart';
import '../utils/alert_date_formatter.dart';
import 'alert_state_pill.dart';
import 'alert_type_icon.dart';

/// "Mis alertas" list card: type icon tile, type name, formatted date and
/// the state pill. [historical] switches the type icon tile's colors
/// (primary tint for an "Activas" card, slate for a "Historial" card).
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    this.historical = false,
  });

  final CitizenAlertEntity alert;
  final VoidCallback onTap;
  final bool historical;

  @override
  Widget build(BuildContext context) {
    // Slate-100/slate-600 for a "Historial" card's type tile happen to be
    // an exact hex match for AppColors.neutral's background/text (same
    // convention as U4's SMS row reusing AppColors.resuelta for its exact
    // hex match) — reused rather than adding a duplicate pair of tokens.
    final tileBackground = historical ? AppColors.neutral.background : AppColors.primaryTint;
    final tileIconColor = historical ? AppColors.neutral.text : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                key: const ValueKey('alert-card-type-tile'),
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(alertTypeIcon(alert.typeName), color: tileIconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.typeName,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatAlertDate(alert.creationDate),
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AlertStatePill(stateName: alert.stateName),
            ],
          ),
        ),
      ),
    );
  }
}
