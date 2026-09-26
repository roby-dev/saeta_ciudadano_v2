import 'package:flutter/foundation.dart';
import '../../domain/entities/citizen_alert_entity.dart';

/// Alerts grouped into "Activas" (pending or in-process) and "Historial"
/// (resolved, cancelled or unknown state), preserving each alert's
/// relative order from the input list.
@immutable
class GroupedAlerts {
  const GroupedAlerts({required this.active, required this.history});

  final List<CitizenAlertEntity> active;
  final List<CitizenAlertEntity> history;
}

GroupedAlerts groupAlerts(List<CitizenAlertEntity> alerts) {
  final active = <CitizenAlertEntity>[];
  final history = <CitizenAlertEntity>[];
  for (final alert in alerts) {
    if (alert.isPending || alert.isInProcess) {
      active.add(alert);
    } else {
      history.add(alert);
    }
  }
  return GroupedAlerts(active: active, history: history);
}
