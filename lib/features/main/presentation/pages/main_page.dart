import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/storage/secure_storage.dart';
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: provider.setIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency),
            label: 'Emergencia',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
