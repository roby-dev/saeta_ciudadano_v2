import 'package:flutter/foundation.dart';
import '../../domain/entities/citizen_alert_entity.dart';

/// "Mis alertas" summary row counts, derived from the already-loaded
/// [CitizenAlertEntity] list — no separate backend call.
@immutable
class AlertsSummary {
  const AlertsSummary({
    required this.total,
    required this.active,
    required this.resolved,
  });

  final int total;

  /// Pending + in-process.
  final int active;

  /// Resolved only (cancelled/unknown alerts count toward [total] but not
  /// [active] or [resolved], matching the Activas/Historial grouping in
  /// `alerts_grouping.dart`).
  final int resolved;
}

AlertsSummary computeAlertsSummary(List<CitizenAlertEntity> alerts) {
  var active = 0;
  var resolved = 0;
  for (final alert in alerts) {
    if (alert.isPending || alert.isInProcess) active++;
    if (alert.isResolved) resolved++;
  }
  return AlertsSummary(total: alerts.length, active: active, resolved: resolved);
}
