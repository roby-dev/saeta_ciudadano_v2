import 'package:flutter/foundation.dart';
import '../../domain/entities/citizen_alert_entity.dart';

/// One step in the alert detail sheet's "Seguimiento" tracking timeline.
@immutable
class AlertTimelineStep {
  const AlertTimelineStep({
    required this.label,
    required this.dateText,
    required this.completed,
    required this.emerald,
  });

  final String label;

  /// The step's raw date string, or `null` when the step hasn't been
  /// reached yet (the widget then shows "Pendiente").
  final String? dateText;

  final bool completed;

  /// `true` only for the completed final step (Resuelta/Cancelada) — it
  /// renders emerald instead of primary.
  final bool emerald;
}

bool _hasDate(String? value) => value != null && value.isNotEmpty;

/// The 3 fixed timeline steps for [alert]: Reportada (always completed, has
/// `creationDate`), En atención (completed once `attentionDate` is set) and
/// Resuelta/Cancelada (completed once `culminationDate` is set; labeled
/// "Cancelada" when [CitizenAlertEntity.isCancelled], "Resuelta" otherwise).
List<AlertTimelineStep> alertTimelineSteps(CitizenAlertEntity alert) {
  final finalLabel = alert.isCancelled ? 'Cancelada' : 'Resuelta';
  final finalDone = _hasDate(alert.culminationDate);
  final attentionDone = _hasDate(alert.attentionDate);

  return [
    AlertTimelineStep(
      label: 'Reportada',
      dateText: alert.creationDate,
      completed: true,
      emerald: false,
    ),
    AlertTimelineStep(
      label: 'En atención',
      dateText: attentionDone ? alert.attentionDate : null,
      completed: attentionDone,
      emerald: false,
    ),
    AlertTimelineStep(
      label: finalLabel,
      dateText: finalDone ? alert.culminationDate : null,
      completed: finalDone,
      emerald: finalDone,
    ),
  ];
}
