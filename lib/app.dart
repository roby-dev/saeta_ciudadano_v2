import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/network/session_expired_notifier.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/main/presentation/pages/main_page.dart';
import 'features/register/presentation/bloc/register_bloc.dart';
import 'features/register/presentation/pages/register_page.dart';
import 'service_locator.dart';

final _router = GoRouter(
  initialLocation: AppConstants.routeSplash,
  routes: [
    GoRoute(
      path: AppConstants.routeSplash,
      builder: (_, __) => const SplashPage(),
    ),
    GoRoute(
      path: AppConstants.routeLogin,
      builder: (_, __) => const LoginPage(),
    ),
    GoRoute(
      path: AppConstants.routeRegister,
      builder: (_, __) => BlocProvider(
        create: (_) => sl<RegisterBloc>(),
        child: const RegisterPage(),
      ),
    ),
    GoRoute(
      path: AppConstants.routeMain,
      builder: (_, state) => MainPage(
        user: state.extra as UserEntity?,
      ),
    ),
  ],
);

class SaetaCiudadanoApp extends StatefulWidget {
  const SaetaCiudadanoApp({super.key});

  @override
  State<SaetaCiudadanoApp> createState() => _SaetaCiudadanoAppState();
}

class _SaetaCiudadanoAppState extends State<SaetaCiudadanoApp> {
  StreamSubscription<void>? _sessionExpiredSubscription;

  @override
  void initState() {
    super.initState();
    // Reuses the same navigation target as the manual logout flow
    // (profile_view.dart): the interceptor already cleared the stored
    // session, this just takes the user back to the login screen.
    _sessionExpiredSubscription =
        sl<SessionExpiredNotifier>().stream.listen((_) {
      _router.go(AppConstants.routeLogin);
    });
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Saeta Ciudadano',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
          ),
          useMaterial3: true,
        ),
        routerConfig: _router,
      ),
    );
  }
}
