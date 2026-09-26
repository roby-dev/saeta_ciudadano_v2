import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../emergency_contacts/presentation/widgets/emergency_contacts_section.dart';
import '../../../profile/presentation/pages/profile_edit_page.dart';
import '../providers/main_navigation_provider.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  void _onLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 40),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<MainNavigationProvider>();
              await provider.logout();
              if (context.mounted) {
                context.go(AppConstants.routeLogin);
              }
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<MainNavigationProvider>().currentUser;

    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : 'Ciudadano Saeta';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final dni = user?.dni ?? '';
    final statusAccount = user?.stateAccount ?? 'HABILITADO';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: user == null
                  ? null
                  : () {
                      // Captured here (still inside MainPage's
                      // MultiProvider) rather than inside ProfileEditPage
                      // itself, since the pushed route sits above that
                      // MultiProvider in the widget tree — see
                      // ProfileEditPage's doc comment.
                      final setUser =
                          context.read<MainNavigationProvider>().setUser;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileEditPage(
                            user: user,
                            onUpdated: setUser,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar perfil'),
            ),
            const SizedBox(height: 12),

            // User Info Cards
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('DNI'),
                    subtitle: Text(dni.isNotEmpty ? dni : 'No especificado'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Teléfono'),
                    subtitle: Text(phone.isNotEmpty ? phone : 'No especificado'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Estado de Cuenta'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusAccount,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Emergency contacts + SMS-on-alert preference
            const EmergencyContactsSection(),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onLogout(context),
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
