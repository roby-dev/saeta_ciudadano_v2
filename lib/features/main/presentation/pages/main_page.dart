import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/main_navigation_provider.dart';
import 'alerts_view.dart';
import 'emergency_view.dart';
import 'profile_view.dart';

import '../../../alerts/presentation/providers/alerts_provider.dart';
import '../../../emergency/presentation/providers/emergency_provider.dart';
import '../../../emergency_contacts/presentation/providers/emergency_contacts_provider.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key, this.user});

  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MainNavigationProvider>(
          create: (_) => MainNavigationProvider(
            storage: sl<SecureStorage>(),
            realtimeService: sl<RealtimeService>(),
            initialUser: user,
          ),
        ),
        ChangeNotifierProvider<EmergencyProvider>(
          create: (_) => sl<EmergencyProvider>(),
        ),
        ChangeNotifierProvider<AlertsProvider>(
          create: (_) => sl<AlertsProvider>(),
        ),
        ChangeNotifierProvider<EmergencyContactsProvider>(
          create: (_) => sl<EmergencyContactsProvider>()..load(),
        ),
      ],
      child: const _MainScaffold(),
    );
  }
}

class _MainScaffold extends StatelessWidget {
  const _MainScaffold();

  static const List<Widget> _views = [
    EmergencyView(),
    AlertsView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MainNavigationProvider>();
    final currentIndex = provider.currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _views,
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: currentIndex,
        onDestinationSelected: provider.setIndex,
      ),
    );
  }
}

/// Bottom navigation for [MainPage]: white background, top border, 3
/// Spanish-labeled items, and a 3px top indicator bar + semibold label on
/// the active item (per the approved redesign canvas). A standalone public
/// widget so it stays unit-testable without standing up every provider
/// [MainPage] wires (realtime service, secure storage, alerts/emergency
/// providers).
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<_NavItemData> _items = [
    _NavItemData(
      icon: Icons.emergency_outlined,
      selectedIcon: Icons.emergency,
      label: 'Emergencia',
    ),
    _NavItemData(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Alertas',
    ),
    _NavItemData(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomNavHeight,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    data: _items[i],
                    selected: i == currentIndex,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: AppDimens.bottomNavIndicatorThickness,
            color: selected ? AppColors.primary : Colors.transparent,
          ),
          const SizedBox(height: 6),
          Icon(selected ? data.selectedIcon : data.icon, color: color),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
