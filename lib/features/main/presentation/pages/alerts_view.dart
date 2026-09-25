import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/main_navigation_provider.dart';
import '../../../alerts/presentation/providers/alerts_provider.dart';
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
    final theme = Theme.of(context);
    final provider = context.watch<AlertsProvider>();
    final alerts = provider.alerts;
    final isLoading = provider.isLoading;
    final errorMsg = provider.errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Alertas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => provider.refreshAlerts(),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando historial de alertas...'),
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
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudieron cargar las alertas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
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
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 80,
                            color: theme.colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes alertas registradas',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Las alertas que reportes o atiendas aparecerán aquí con su estado en tiempo real.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              context.read<MainNavigationProvider>().setIndex(0);
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

          return RefreshIndicator(
            onRefresh: () => provider.refreshAlerts(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return AlertCard(
                  alert: alert,
                  onTap: () => AlertDetailSheet.show(context, alert),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
