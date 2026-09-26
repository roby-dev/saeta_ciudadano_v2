import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/citizen_alert_entity.dart';
import '../providers/alerts_provider.dart';
import '../utils/alert_date_formatter.dart';
import '../utils/alert_short_id.dart';
import '../utils/alert_timeline.dart';
import '../utils/tel_uri_builder.dart';
import 'alert_map_card.dart';
import 'alert_state_pill.dart';
import 'alert_type_icon.dart';

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
      backgroundColor: AppColors.background,
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

  static const TelUriBuilder _telUriBuilder = TelUriBuilder();

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

  Future<void> _callAttendedByPhone(String phone) async {
    try {
      await launchUrl(_telUriBuilder.build(phone));
    } catch (_) {
      // Best-effort only, same convention as AlertMapCard's
      // "Abrir en Google Maps" launch: never breaks the detail view.
    }
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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SummaryCard(alert: alert),
              const SizedBox(height: 16),
              _TimelineCard(alert: alert),
              const SizedBox(height: 16),
              _AttentionDataCard(
                alert: alert,
                onCallAttendedBy: _callAttendedByPhone,
              ),
              if (alert.isResolved) ...[
                const SizedBox(height: 16),
                _RatingCard(
                  currentScore: _currentScore,
                  onScoreChanged: (value) =>
                      setState(() => _currentScore = value),
                  commentaryController: _commentaryController,
                  isSubmitting: _isSubmitting,
                  onSubmit: _submitFeedback,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.alert});

  final CitizenAlertEntity alert;

  @override
  Widget build(BuildContext context) {
    final shortId = alertShortId(alert.id);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(alertTypeIcon(alert.typeName), color: AppColors.primary),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    if (shortId != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '#$shortId',
                        style: const TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AlertStatePill(stateName: alert.stateName),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          AlertMapCard(
            latitude: alert.latitude,
            longitude: alert.longitude,
            stateName: alert.stateName,
            typeName: alert.typeName,
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.alert});

  final CitizenAlertEntity alert;

  @override
  Widget build(BuildContext context) {
    final steps = alertTimelineSteps(alert);

    return SectionCard(
      title: 'Seguimiento',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineStepRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }
}

class _TimelineStepRow extends StatelessWidget {
  const _TimelineStepRow({required this.step, required this.isLast});

  final AlertTimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final circleColor = step.completed
        ? (step.emerald ? AppColors.resuelta.text : AppColors.primary)
        : AppColors.surface;
    final connectorColor =
        step.completed ? AppColors.primary : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: step.completed
                      ? null
                      : Border.all(color: AppColors.secondaryBorder, width: 2),
                ),
                child: step.completed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: connectorColor),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.completed && step.dateText != null
                        ? formatAlertDate(step.dateText!)
                        : 'Pendiente',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      color: step.completed ? AppColors.text : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionDataCard extends StatelessWidget {
  const _AttentionDataCard({required this.alert, required this.onCallAttendedBy});

  final CitizenAlertEntity alert;
  final void Function(String phone) onCallAttendedBy;

  @override
  Widget build(BuildContext context) {
    final name = alert.attendedByName;
    final phone = alert.attendedByPhone;

    return SectionCard(
      title: 'Datos de la atención',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (name != null) ...[
            _InfoRow(label: 'Personal que atendió', value: name),
            const SizedBox(height: 12),
          ],
          if (phone != null) ...[
            _PhoneRow(phone: phone, onCall: () => onCallAttendedBy(phone)),
            const SizedBox(height: 12),
          ],
          _InfoRow(
            label: 'Ubicación GPS',
            value:
                '${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}',
            mono: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: mono ? AppFonts.mono : AppFonts.sans,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone, required this.onCall});

  final String phone;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoRow(
            label: 'Teléfono de contacto',
            value: phone,
            mono: true,
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Llamar',
          child: Material(
            color: AppColors.primaryTint,
            shape: const CircleBorder(),
            child: InkWell(
              key: const ValueKey('attention-call-button'),
              customBorder: const CircleBorder(),
              onTap: onCall,
              child: const SizedBox(
                width: AppDimens.minTouchTarget,
                height: AppDimens.minTouchTarget,
                child: Icon(Icons.call, color: AppColors.primary, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.currentScore,
    required this.onScoreChanged,
    required this.commentaryController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final double currentScore;
  final ValueChanged<double> onScoreChanged;
  final TextEditingController commentaryController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Calificación de la atención',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1.0;
              final filled = currentScore >= starValue;
              return InkResponse(
                onTap: () => onScoreChanged(starValue),
                child: SizedBox(
                  width: AppDimens.minTouchTarget,
                  height: AppDimens.minTouchTarget,
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    // #F59E0B/#CBD5E1 exact hex match the canvas's amber-500
                    // fill and slate-300 empty state — reused from the
                    // existing pendiente/secondaryBorder tokens rather than
                    // adding duplicate ones (same convention as AlertCard's
                    // historical tile).
                    color: filled ? AppColors.pendiente.dot : AppColors.secondaryBorder,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentaryController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Comentario (opcional)',
              hintText: 'Describe cómo fue la respuesta de seguridad...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(isSubmitting ? 'Guardando...' : 'Enviar calificación'),
          ),
        ],
      ),
    );
  }
}
