import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/saeta_button.dart';
import '../widgets/saeta_logo.dart';
import '../widgets/saeta_text_field.dart';

/// Height of the blue header band behind the hero card.
const double _bandHeight = 280;

/// How much the hero card overlaps the band above it.
const double _cardOverlap = 72;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthLoginSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            rememberMe: _rememberMe,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go(AppConstants.routeMain, extra: state.user);
          } else if (state is AuthFailure) {
            _showError(context, state.message);
          }
        },
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: _bandHeight,
                        width: double.infinity,
                        color: AppColors.primary,
                        alignment: Alignment.center,
                        child: const SaetaLogo.brandMark(
                          subtitle: 'Ciudadano · Seguridad ciudadana',
                        ),
                      ),
                      Transform.translate(
                        // Overlaps the card over the band above it — a
                        // paint-only shift (Container.margin requires
                        // non-negative insets), so it leaves a harmless
                        // sliver of extra scrollable space below the card.
                        offset: const Offset(0, -_cardOverlap),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadii.heroCard),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.heading.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Iniciar sesión',
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.heading,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ingresa con tu cuenta registrada.',
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 14,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SaetaTextField(
                                  label: 'Correo electrónico',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'El correo es obligatorio';
                                    }
                                    final emailRegex = RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(value.trim())) {
                                      return 'Ingresa un correo válido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                SaetaTextField(
                                  label: 'Contraseña',
                                  controller: _passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _onSubmit(),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'La contraseña es obligatoria';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                          () => _rememberMe = v ?? false),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _rememberMe = !_rememberMe),
                                      child: const Text(
                                        'Recordarme',
                                        style: TextStyle(
                                          fontFamily: AppFonts.sans,
                                          fontSize: 14,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final isLoading = state is AuthLoading;
                                    return SaetaButton.primary(
                                      label: 'Ingresar',
                                      isLoading: isLoading,
                                      onPressed: _onSubmit,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            '¿No tienes cuenta? ',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () =>
                                    context.push(AppConstants.routeRegister),
                            child: const Text(
                              'Regístrate',
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon:
            const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
