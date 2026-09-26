import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/widgets/saeta_button.dart';
import '../../../auth/presentation/widgets/saeta_logo.dart';
import '../../../auth/presentation/widgets/saeta_text_field.dart';
import '../bloc/register_bloc.dart';
import '../bloc/register_event.dart';
import '../bloc/register_state.dart';

/// Height of the blue header band behind the hero card.
const double _bandHeight = 220;

/// How much the hero card overlaps the band above it.
const double _cardOverlap = 56;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _dniController.dispose();
    _nameController.dispose();
    _lastnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<RegisterBloc>().add(
          RegisterSubmitted(
            dni: _dniController.text.trim(),
            name: _nameController.text.trim(),
            lastname: _lastnameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<RegisterBloc, RegisterState>(
        listener: (context, state) {
          if (state is RegisterDniFound) {
            _nameController.text = state.names;
            _lastnameController.text = state.lastname;
          } else if (state is RegisterDniNotFound) {
            _nameController.clear();
            _lastnameController.clear();
            _showError(context, state.message);
          } else if (state is RegisterSuccess) {
            context.go(AppConstants.routeMain, extra: state.user);
          } else if (state is RegisterFailure) {
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
                                  'Crear cuenta',
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.heading,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Completa tus datos para registrarte.',
                                  style: TextStyle(
                                    fontFamily: AppFonts.sans,
                                    fontSize: 14,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // DNI (drives the RENIEC auto-fill lookup)
                                BlocBuilder<RegisterBloc, RegisterState>(
                                  builder: (context, state) {
                                    final isLookingUp =
                                        state is RegisterDniLookingUp;
                                    return SaetaTextField(
                                      key: const Key('registerDniField'),
                                      label: 'DNI',
                                      controller: _dniController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      isLoading: isLookingUp,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(8),
                                      ],
                                      onChanged: (value) => context
                                          .read<RegisterBloc>()
                                          .add(RegisterDniChanged(value)),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'El DNI es obligatorio';
                                        }
                                        if (v.length != 8) {
                                          return 'El DNI debe tener 8 dígitos';
                                        }
                                        return null;
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Name (auto-filled, read-only)
                                BlocBuilder<RegisterBloc, RegisterState>(
                                  builder: (context, state) {
                                    final isLookingUp =
                                        state is RegisterDniLookingUp;
                                    return SaetaTextField(
                                      key: const Key('registerNameField'),
                                      label: 'Nombre',
                                      controller: _nameController,
                                      readOnly: true,
                                      isLoading: isLookingUp,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'El nombre es obligatorio'
                                              : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Lastname (auto-filled, read-only)
                                BlocBuilder<RegisterBloc, RegisterState>(
                                  builder: (context, state) {
                                    final isLookingUp =
                                        state is RegisterDniLookingUp;
                                    return SaetaTextField(
                                      key: const Key('registerLastnameField'),
                                      label: 'Apellido',
                                      controller: _lastnameController,
                                      readOnly: true,
                                      isLoading: isLookingUp,
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'El apellido es obligatorio'
                                              : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Phone
                                SaetaTextField(
                                  key: const Key('registerPhoneField'),
                                  label: 'Teléfono',
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(9),
                                  ],
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'El teléfono es obligatorio';
                                    }
                                    if (v.length != 9) {
                                      return 'El teléfono debe tener 9 dígitos';
                                    }
                                    if (!v.startsWith('9')) {
                                      return 'El teléfono debe empezar con 9';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Email (optional)
                                SaetaTextField(
                                  key: const Key('registerEmailField'),
                                  label: 'Correo electrónico',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null; // optional
                                    }
                                    final emailRegex = RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(v.trim())) {
                                      return 'Ingresa un correo válido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password
                                SaetaTextField(
                                  key: const Key('registerPasswordField'),
                                  label: 'Contraseña',
                                  controller: _passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'La contraseña es obligatoria'
                                          : null,
                                ),
                                const SizedBox(height: 16),

                                // Confirm password
                                SaetaTextField(
                                  key:
                                      const Key('registerConfirmPasswordField'),
                                  label: 'Confirmar contraseña',
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _onSubmit(),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Confirma tu contraseña';
                                    }
                                    if (v.trim() !=
                                        _passwordController.text.trim()) {
                                      return 'Las contraseñas no coinciden';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                BlocBuilder<RegisterBloc, RegisterState>(
                                  builder: (context, state) {
                                    final isLoading = state is RegisterLoading;
                                    return SaetaButton.primary(
                                      label: 'Registrarme',
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: BlocBuilder<RegisterBloc, RegisterState>(
                    builder: (context, state) {
                      final isLoading = state is RegisterLoading;
                      return Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            '¿Ya tienes cuenta? ',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading ? null : () => context.pop(),
                            child: const Text(
                              'Inicia sesión',
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
