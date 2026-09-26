import 'package:flutter/material.dart';
import '../../domain/entities/citizen_alert_entity.dart';
import 'alert_state_pill.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
  });

  final CitizenAlertEntity alert;
  final VoidCallback onTap;

  IconData _getTypeIcon(String typeName) {
    final lower = typeName.toLowerCase();
    if (lower.contains('robo')) return Icons.local_police_outlined;
    if (lower.contains('incendio')) return Icons.local_fire_department_outlined;
    if (lower.contains('violencia')) return Icons.family_restroom_outlined;
    if (lower.contains('accidente')) return Icons.car_crash_outlined;
    if (lower.contains('pandillaje')) return Icons.groups_outlined;
    return Icons.warning_amber_rounded;
  }

  Color _getStatusColor(BuildContext context) {
    if (alert.isResolved) return Colors.green.shade700;
    if (alert.isInProcess) return Colors.blue.shade700;
    if (alert.isPending) return Colors.orange.shade800;
    if (alert.isCancelled) return Colors.grey.shade600;
    return Theme.of(context).colorScheme.primary;
  }

  Color _getStatusBackgroundColor(BuildContext context) {
    if (alert.isResolved) return Colors.green.shade50;
    if (alert.isInProcess) return Colors.blue.shade50;
    if (alert.isPending) return Colors.orange.shade50;
    if (alert.isCancelled) return Colors.grey.shade100;
    return Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final statusBgColor = _getStatusBackgroundColor(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: statusBgColor,
                    child: Icon(
                      _getTypeIcon(alert.typeName),
                      color: statusColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.typeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              alert.creationDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AlertStatePill(stateName: alert.stateName),
                ],
              ),
              if (alert.attendedByName != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Atendido por: ${alert.attendedByName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (alert.score != null && alert.score! > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < alert.score!.round() ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber.shade700,
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      '${alert.score!.toStringAsFixed(1)} / 5',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
