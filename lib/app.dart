import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/network/account_disabled_notifier.dart';
import 'core/network/session_expired_notifier.dart';
import 'core/realtime/realtime_service.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
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
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<void>? _sessionExpiredSubscription;
  StreamSubscription<String>? _accountDisabledSubscription;

  @override
  void initState() {
    super.initState();
    // Reuses the same navigation target as the manual logout flow
    // (profile_view.dart): the interceptor already cleared the stored
    // session, this just takes the user back to the login screen.
    _sessionExpiredSubscription =
        sl<SessionExpiredNotifier>().stream.listen((_) {
      sl<RealtimeService>().disconnect();
      _router.go(AppConstants.routeLogin);
    });
    // `disableUser`: the realtime service already cleared the session and
    // disconnected the socket (see RealtimeServiceImpl); this just navigates
    // back to login and surfaces the server-provided message.
    _accountDisabledSubscription =
        sl<AccountDisabledNotifier>().stream.listen((message) {
      _router.go(AppConstants.routeLogin);
      _messengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(message)));
    });
    // Covers "connect on app start with a stored session"; a no-op today
    // since there is no token yet without a prior login in this app
    // instance (AuthSessionChecked doesn't restore a session automatically —
    // a pre-existing limitation from T1, not something T3 changes).
    sl<RealtimeService>().connect();
  }

  @override
  void dispose() {
    _sessionExpiredSubscription?.cancel();
    _accountDisabledSubscription?.cancel();
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
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            sl<RealtimeService>().connect();
          }
        },
        child: MaterialApp.router(
          title: 'Saeta Ciudadano',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1565C0),
            ),
            useMaterial3: true,
          ),
          routerConfig: _router,
        ),
      ),
    );
  }
}
