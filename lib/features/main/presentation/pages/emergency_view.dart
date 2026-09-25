import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../alerts/presentation/providers/alerts_provider.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency_contacts/presentation/providers/emergency_contacts_provider.dart';
import '../widgets/emergency_type_card.dart';
import '../widgets/sos_button.dart';

class EmergencyView extends StatelessWidget {
  const EmergencyView({super.key});

  Future<void> _triggerSendAlert(BuildContext context, String alertName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          alertName == 'Emergencia' ? Icons.warning_amber_rounded : Icons.info_outline,
          color: alertName == 'Emergencia' ? Colors.red : Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: Text('Reportar $alertName'),
        content: Text(
          '¿Estás seguro de enviar una alerta de "$alertName" con tu ubicación actual a la central de seguridad?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: alertName == 'Emergencia' ? Colors.red.shade700 : null,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ENVIAR ALERTA'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<EmergencyProvider>();
    final success = await provider.sendAlert(alertName);

    if (!context.mounted) return;

    if (success) {
      // Refresh the alerts history list immediately
      context.read<AlertsProvider>().refreshAlerts();

      // Open the SMS composer for emergency contacts (only if the user has
      // the preference on and has contacts); never blocks or fails the
      // alert flow above, which already succeeded.
      final sentAlert = provider.lastSentAlert;
      if (sentAlert != null) {
        await context.read<EmergencyContactsProvider>().sendSmsForAlert(
              alertTypeName: alertName,
              latitude: sentAlert.latitude,
              longitude: sentAlert.longitude,
            );
      }
      if (!context.mounted) return;

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
          title: const Text('Alerta Enviada'),
          content: Text(
            'Tu alerta de $alertName fue registrada exitosamente en la central.\n'
            'Personal de seguridad se encuentra coordinando la atención.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } else {
      final errorMsg = provider.errorMessage ?? 'No se pudo enviar la alerta';
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
          title: const Text('Aviso'),
          content: Text(errorMsg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.primary;
    final isSending = context.watch<EmergencyProvider>().isSendingAlert;

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Zona de Alertas',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona el tipo de incidente para reportar inmediatamente',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // 2x3 Grid of Alert Types
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    EmergencyTypeCard(
                      title: 'Robo',
                      icon: Icons.local_police_outlined,
                      backgroundColor: cardColor,
                      onTap: () => _triggerSendAlert(context, 'Robo'),
                    ),
                    EmergencyTypeCard(
                      title: 'Incendio',
                      icon: Icons.local_fire_department_outlined,
                      backgroundColor: cardColor,
                      onTap: () => _triggerSendAlert(context, 'Incendio'),
                    ),
                    EmergencyTypeCard(
                      title: 'Violencia\nFamiliar',
                      icon: Icons.family_restroom_outlined,
                      backgroundColor: cardColor,
                      onTap: () => _triggerSendAlert(context, 'Violencia Familiar'),
                    ),
                    EmergencyTypeCard(
                      title: 'Accidente\nTránsito',
                      icon: Icons.car_crash_outlined,
                      backgroundColor: cardColor,
                      onTap: () => _triggerSendAlert(context, 'Accidente de Tránsito'),
                    ),
                    EmergencyTypeCard(
                      title: 'Pandillaje',
                      icon: Icons.groups_outlined,
                      backgroundColor: cardColor,
                      onTap: () => _triggerSendAlert(context, 'Pandillaje'),
                    ),
                    EmergencyTypeCard(
                      title: 'Otro',
                      icon: Icons.help_outline,
                      backgroundColor: cardColor,
                      onTap: () => _triggerSendAlert(context, 'Otro'),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Big SOS Button
                SosButton(
                  onPressed: () => _triggerSendAlert(context, 'Emergencia'),
                ),
              ],
            ),
          ),
        ),

        // Loading overlay when sending an alert
        if (isSending)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            child: const Center(
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text(
                        'Enviando alerta a la central...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Obteniendo ubicación GPS',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
