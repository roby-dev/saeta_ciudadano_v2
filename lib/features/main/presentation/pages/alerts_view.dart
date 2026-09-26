import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/main_navigation_provider.dart';
import '../../../alerts/presentation/providers/alerts_provider.dart';
import '../../../alerts/presentation/utils/alerts_grouping.dart';
import '../../../alerts/presentation/utils/alerts_summary.dart';
import '../../../alerts/presentation/widgets/alert_card.dart';
import '../../../alerts/presentation/widgets/alert_detail_sheet.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlerts();
    });
  }

  void _loadAlerts() {
    final user = context.read<MainNavigationProvider>().currentUser;
    if (user != null && user.id.isNotEmpty) {
      context.read<AlertsProvider>().loadAlerts(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertsProvider>();
    final alerts = provider.alerts;
    final isLoading = provider.isLoading;
    final errorMsg = provider.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(onRefresh: () => provider.refreshAlerts()),
          Expanded(
            child: Builder(
              builder: (context) {
                if (isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Cargando historial de alertas...',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (errorMsg != null && alerts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 64, color: AppColors.danger),
                          const SizedBox(height: 16),
                          const Text(
                            'No se pudieron cargar las alertas',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.heading,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMsg,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: AppFonts.sans,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadAlerts,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (alerts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => provider.refreshAlerts(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 80,
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No tienes alertas registradas',
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.heading,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Las alertas que reportes o atiendas '
                                  'aparecerán aquí con su estado en tiempo '
                                  'real.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () {
                                    context
                                        .read<MainNavigationProvider>()
                                        .setIndex(0);
                                  },
                                  icon: const Icon(Icons.emergency_outlined),
                                  label: const Text('Reportar Emergencia'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final summary = computeAlertsSummary(alerts);
                final grouped = groupAlerts(alerts);

                return RefreshIndicator(
                  onRefresh: () => provider.refreshAlerts(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    children: [
                      _SummaryRow(summary: summary),
                      const SizedBox(height: 20),
                      if (grouped.active.isNotEmpty) ...[
                        const _SectionHeader(title: 'Activas'),
                        for (final alert in grouped.active)
                          AlertCard(
                            key: ValueKey('alert-card-${alert.id}'),
                            alert: alert,
                            onTap: () => AlertDetailSheet.show(context, alert),
                          ),
                        const SizedBox(height: 20),
                      ],
                      if (grouped.history.isNotEmpty) ...[
                        const _SectionHeader(title: 'Historial'),
                        for (final alert in grouped.history)
                          AlertCard(
                            key: ValueKey('alert-card-${alert.id}'),
                            alert: alert,
                            historical: true,
                            onTap: () => AlertDetailSheet.show(context, alert),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The solid primary header band: title, "live" subtitle and the refresh
/// button.
class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mis alertas',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Actualizar',
                onPressed: onRefresh,
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.liveDot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Actualización en tiempo real',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12,
                  color: AppColors.onPrimaryMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The 3 equal white bordered "Total"/"Activas"/"Resueltas" tiles.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final AlertsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Total',
              value: summary.total,
              valueColor: AppColors.heading,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Activas',
              value: summary.active,
              valueColor: AppColors.enProceso.text,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryTile(
              label: 'Resueltas',
              value: summary.resolved,
              valueColor: AppColors.resuelta.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final int value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.heading,
        ),
      ),
    );
  }
}
