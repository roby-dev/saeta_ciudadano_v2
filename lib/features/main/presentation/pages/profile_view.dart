import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../emergency_contacts/presentation/widgets/emergency_contacts_section.dart';
import '../../../profile/presentation/pages/profile_edit_page.dart';
import '../../../profile/presentation/utils/account_state_label.dart';
import '../../../profile/presentation/widgets/avatar_section.dart';
import '../providers/main_navigation_provider.dart';

/// How much the identity hero card overlaps the header band above it.
const double _cardOverlap = 48;

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  void _onLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.logout_rounded, color: AppColors.cancelada.text, size: 40),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
    final user = context.watch<MainNavigationProvider>().currentUser;

    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : 'Ciudadano Saeta';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final dni = user?.dni ?? '';
    final accountState = accountStateLabel(user?.stateAccount ?? 'HABILITADO');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
                child: const Text(
                  'Mi perfil',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Transform.translate(
                // Paint-only overlap shift (Container.margin asserts on
                // negative insets) — same technique as U3/U4's hero cards,
                // here wrapping the identity card *and* everything below it
                // so there's no visual gap between them; leaves a harmless
                // sliver of extra scrollable space at the very bottom.
                offset: const Offset(0, -_cardOverlap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AvatarSection(
                            user: user,
                            onUpdated: context.read<MainNavigationProvider>().setUser,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.heading,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      fontFamily: AppFonts.sans,
                                      fontSize: 13,
                                      color: AppColors.muted,
                                    ),
                                    children: [
                                      const TextSpan(text: 'DNI '),
                                      TextSpan(
                                        text: dni.isNotEmpty ? dni : 'No especificado',
                                        style: const TextStyle(fontFamily: AppFonts.mono),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _AccountStatePill(label: accountState),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionCard(
                            title: 'Datos personales',
                            trailing: TextButton.icon(
                              onPressed: user == null
                                  ? null
                                  : () {
                                      // Captured here (still inside
                                      // MainPage's MultiProvider) rather
                                      // than inside ProfileEditPage itself —
                                      // see ProfileEditPage's doc comment.
                                      final setUser = context
                                          .read<MainNavigationProvider>()
                                          .setUser;
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ProfileEditPage(
                                            user: user,
                                            onUpdated: setUser,
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Editar'),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _DataRow(label: 'Correo electrónico', value: email),
                                const SizedBox(height: 12),
                                _DataRow(label: 'Teléfono', value: phone, mono: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const EmergencyContactsSection(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _onLogout(context),
                              icon: Icon(Icons.logout_rounded, color: AppColors.cancelada.text),
                              label: Text(
                                'Cerrar sesión',
                                style: TextStyle(
                                  fontFamily: AppFonts.sans,
                                  color: AppColors.cancelada.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.cancelada.border),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountStatePill extends StatelessWidget {
  const _AccountStatePill({required this.label});

  final AccountStateLabel label;

  @override
  Widget build(BuildContext context) {
    final palette = label.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: palette.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.text,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              color: palette.text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          value.isNotEmpty ? value : 'No especificado',
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
