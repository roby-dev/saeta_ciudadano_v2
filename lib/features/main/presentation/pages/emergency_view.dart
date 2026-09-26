import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../alerts/presentation/providers/alerts_provider.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency_contacts/presentation/providers/emergency_contacts_provider.dart';
import '../providers/main_navigation_provider.dart';
import '../widgets/emergency_type_card.dart';
import '../widgets/sos_button.dart';

/// How much the hero card overlaps the header band above it.
const double _cardOverlap = 56;

/// The "Reportar por tipo de incidente" grid, in the approved canvas order.
/// [type] is the backend-facing alert type name passed to
/// [EmergencyProvider.sendAlert]/the SMS body; [label] is the grid's
/// single-line Spanish display text.
class _IncidentType {
  const _IncidentType({
    required this.label,
    required this.type,
    required this.icon,
  });

  final String label;
  final String type;
  final IconData icon;
}

const _incidentTypes = [
  _IncidentType(
    label: 'Robo',
    type: 'Robo',
    icon: Icons.local_police_outlined,
  ),
  _IncidentType(
    label: 'Incendio',
    type: 'Incendio',
    icon: Icons.local_fire_department_outlined,
  ),
  _IncidentType(
    label: 'Accidente de tránsito',
    type: 'Accidente de Tránsito',
    icon: Icons.car_crash_outlined,
  ),
  _IncidentType(
    label: 'Pandillaje',
    type: 'Pandillaje',
    icon: Icons.groups_outlined,
  ),
  _IncidentType(
    label: 'Violencia familiar',
    type: 'Violencia Familiar',
    icon: Icons.family_restroom_outlined,
  ),
  _IncidentType(
    label: 'Otro',
    type: 'Otro',
    icon: Icons.help_outline,
  ),
];

/// Icon for the report-confirmation sheet, matched against [_incidentTypes]
/// (case-insensitive); falls back to the SOS/"Emergencia" icon.
IconData _iconForType(String type) {
  for (final t in _incidentTypes) {
    if (t.type.toLowerCase() == type.toLowerCase()) return t.icon;
  }
  return Icons.warning_amber_rounded;
}

/// Up to 2 uppercase initials from [user]'s name/lastname; "CS" ("Ciudadano
/// Saeta") when neither is available.
String _initials(UserEntity? user) {
  final first = user?.name.trim() ?? '';
  final last = user?.lastname.trim() ?? '';
  final initials =
      '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
          .toUpperCase();
  return initials.isNotEmpty ? initials : 'CS';
}

class EmergencyView extends StatelessWidget {
  const EmergencyView({super.key});

  Future<void> _triggerSendAlert(BuildContext context, String alertName) async {
    final contactsProvider = context.read<EmergencyContactsProvider>();
    final smsContactsCount =
        contactsProvider.sendSmsOnAlert ? contactsProvider.contacts.length : 0;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReportConfirmationSheet(
        alertName: alertName,
        smsContactsCount: smsContactsCount,
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
          icon: Icon(Icons.check_circle_outline,
              color: AppColors.resuelta.text, size: 52),
          title: const Text('Alerta enviada'),
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
          icon: const Icon(Icons.error_outline,
              color: AppColors.danger, size: 48),
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
    final navProvider = context.watch<MainNavigationProvider>();
    final user = navProvider.currentUser;
    final isSending = context.watch<EmergencyProvider>().isSendingAlert;
    final contactsProvider = context.watch<EmergencyContactsProvider>();

    void goToProfile() => navProvider.setIndex(2);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(user: user, onAvatarTap: goToProfile),
                  Transform.translate(
                    // Paint-only overlap shift (Container.margin requires
                    // non-negative insets) — leaves a harmless sliver of
                    // extra scrollable space below the card.
                    offset: const Offset(0, -_cardOverlap),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.heroCard),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.heading.withValues(alpha: 0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: SosButton(
                              onPressed: () =>
                                  _triggerSendAlert(context, 'Emergencia'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Presiona para enviar tu ubicación a la central '
                            'de seguridad.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'Reportar por tipo de incidente',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.heading,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            shrinkWrap: true,
                            childAspectRatio: 0.95,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final t in _incidentTypes)
                                EmergencyTypeCard(
                                  title: t.label,
                                  icon: t.icon,
                                  onTap: () =>
                                      _triggerSendAlert(context, t.type),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SmsRow(
                            enabled: contactsProvider.sendSmsOnAlert,
                            contactsCount: contactsProvider.contacts.length,
                            onTap: goToProfile,
                          ),
                        ],
                      ),
                    ),
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
      ),
    );
  }
}

/// The blue header band: brand mark, avatar (→ Perfil tab) and greeting.
///
/// No GPS-status pill: the app has no cheap/already-known GPS state at this
/// point (see `odd/tasks/ui-redesign.md` U4 notes) and adding one is out of
/// this presentation-only task's scope.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onAvatarTap});

  final UserEntity? user;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Ciudadano';

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 76),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SAETA',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Ciudadano',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 12,
                      color: AppColors.onPrimaryMuted,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryDark,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    _initials(user),
                    style: const TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hola, $firstName',
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// "SMS a contactos de emergencia" row card, under the incident grid.
class _SmsRow extends StatelessWidget {
  const _SmsRow({
    required this.enabled,
    required this.contactsCount,
    required this.onTap,
  });

  final bool enabled;
  final int contactsCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        enabled ? 'Activado · $contactsCount contactos' : 'Desactivado';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.resuelta.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.message_outlined,
                    color: AppColors.resuelta.text, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMS a contactos de emergencia',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet confirming "Reportar {tipo}" before sending an alert.
class _ReportConfirmationSheet extends StatelessWidget {
  const _ReportConfirmationSheet({
    required this.alertName,
    required this.smsContactsCount,
  });

  final String alertName;
  final int smsContactsCount;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.dangerTintAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(alertName), color: AppColors.danger),
            ),
            const SizedBox(height: 12),
            Text(
              'Reportar ${alertName.toLowerCase()}',
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.heading,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Confirma para alertar a la central de seguridad.',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Column(
                children: [
                  const _InfoRow(
                    label: 'Ubicación GPS',
                    value: 'Se obtendrá al enviar',
                    mono: true,
                  ),
                  if (smsContactsCount > 0) const Divider(height: 1),
                  if (smsContactsCount > 0)
                    _InfoRow(
                      label: 'SMS a contactos de emergencia',
                      value: 'Se abrirá el mensajero para $smsContactsCount '
                          'contactos',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.send),
                label: const Text('Enviar alerta'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: mono ? AppFonts.mono : AppFonts.sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
