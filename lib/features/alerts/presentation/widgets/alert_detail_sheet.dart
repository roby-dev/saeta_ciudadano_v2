import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/citizen_alert_entity.dart';
import '../providers/alerts_provider.dart';
import 'alert_map_card.dart';
import 'alert_state_pill.dart';

class AlertDetailSheet extends StatefulWidget {
  const AlertDetailSheet({
    super.key,
    required this.alert,
  });

  final CitizenAlertEntity alert;

  static Future<void> show(BuildContext context, CitizenAlertEntity alert) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AlertDetailSheet(alert: alert),
    );
  }

  @override
  State<AlertDetailSheet> createState() => _AlertDetailSheetState();
}

class _AlertDetailSheetState extends State<AlertDetailSheet> {
  late double _currentScore;
  final TextEditingController _commentaryController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentScore = widget.alert.score ?? 5.0;
    if (widget.alert.commentary != null) {
      _commentaryController.text = widget.alert.commentary!;
    }
  }

  @override
  void dispose() {
    _commentaryController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    final provider = context.read<AlertsProvider>();
    final success = await provider.submitFeedback(
      alertId: widget.alert.id,
      commentary: _commentaryController.text.trim(),
      score: _currentScore,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por calificar la atención recibida!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final errorMsg = provider.errorMessage ?? 'Error al enviar la calificación';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title and State
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Alerta: ${alert.typeName}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AlertStatePill(stateName: alert.stateName),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),

              // Details List
              _buildDetailTile(
                icon: Icons.calendar_today_outlined,
                label: 'Fecha de Reporte',
                value: alert.creationDate,
              ),
              if (alert.attentionDate != null && alert.attentionDate!.isNotEmpty)
                _buildDetailTile(
                  icon: Icons.schedule_outlined,
                  label: 'Fecha de Atención',
                  value: alert.attentionDate!,
                ),
              if (alert.culminationDate != null && alert.culminationDate!.isNotEmpty)
                _buildDetailTile(
                  icon: Icons.check_circle_outline,
                  label: 'Fecha de Culminación',
                  value: alert.culminationDate!,
                ),
              _buildDetailTile(
                icon: Icons.location_on_outlined,
                label: 'Ubicación GPS',
                value: '${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 12),
              AlertMapCard(
                latitude: alert.latitude,
                longitude: alert.longitude,
                stateName: alert.stateName,
                typeName: alert.typeName,
              ),
              const SizedBox(height: 8),
              if (alert.attendedByName != null)
                _buildDetailTile(
                  icon: Icons.shield_outlined,
                  label: 'Personal que Atendió',
                  value: alert.attendedByName!,
                ),
              if (alert.attendedByPhone != null)
                _buildDetailTile(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono de Contacto',
                  value: alert.attendedByPhone!,
                ),

              const SizedBox(height: 20),

              // Feedback Section (if Resolved)
              if (alert.isResolved) ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Calificación de la Atención',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Stars Rating
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(
                          _currentScore >= starVal
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber.shade700,
                        ),
                        onPressed: () {
                          setState(() {
                            _currentScore = starVal;
                          });
                        },
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Commentary field
                TextField(
                  controller: _commentaryController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Comentario sobre la atención (opcional)',
                    hintText: 'Describe cómo fue la respuesta de seguridad...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit Button
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Guardando...' : 'Enviar Calificación'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
