import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/widgets/saeta_button.dart';
import '../../../auth/presentation/widgets/saeta_text_field.dart';
import '../bloc/register_bloc.dart';
import '../bloc/register_event.dart';
import '../bloc/register_state.dart';

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // DNI
                  _DniField(
                    controller: _dniController,
                    onChanged: (value) {
                      context
                          .read<RegisterBloc>()
                          .add(RegisterDniChanged(value));
                    },
                  ),
                  const SizedBox(height: 16),

                  // Name (auto-filled, read-only)
                  BlocBuilder<RegisterBloc, RegisterState>(
                    builder: (context, state) {
                      final isLookingUp = state is RegisterDniLookingUp;
                      return SaetaTextField(
                        label: 'Name',
                        prefixIcon: Icons.person_outline,
                        controller: _nameController,
                        readOnly: true,
                        isLoading: isLookingUp,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Lastname (auto-filled, read-only)
                  BlocBuilder<RegisterBloc, RegisterState>(
                    builder: (context, state) {
                      final isLookingUp = state is RegisterDniLookingUp;
                      return SaetaTextField(
                        label: 'Lastname',
                        prefixIcon: Icons.person_outline,
                        controller: _lastnameController,
                        readOnly: true,
                        isLoading: isLookingUp,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Lastname is required'
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  SaetaTextField(
                    label: 'Phone',
                    prefixIcon: Icons.phone_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone is required';
                      }
                      if (v.length != 9) {
                        return 'Phone must be 9 digits';
                      }
                      if (!v.startsWith('9')) {
                        return 'Phone must start with 9';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  SaetaTextField(
                    label: 'Email',
                    prefixIcon: Icons.email_outlined,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  SaetaTextField(
                    label: 'Password',
                    prefixIcon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Password is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Confirm password
                  SaetaTextField(
                    label: 'Confirm Password',
                    prefixIcon: Icons.lock_outline,
                    controller: _confirmPasswordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _onSubmit(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v.trim() != _passwordController.text.trim()) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  BlocBuilder<RegisterBloc, RegisterState>(
                    builder: (context, state) {
                      final isLoading = state is RegisterLoading;
                      return Column(
                        children: [
                          SaetaButton.primary(
                            label: 'Register',
                            isLoading: isLoading,
                            onPressed: _onSubmit,
                          ),
                          const SizedBox(height: 12),
                          SaetaButton.outlined(
                            label: 'Cancel',
                            onPressed:
                                isLoading ? null : () => context.pop(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Isolated DNI field widget — handles its own text change notification.
class _DniField extends StatelessWidget {
  const _DniField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: InputDecoration(
        labelText: 'DNI',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.badge_outlined),
        counterText: '',
        suffixIcon: BlocBuilder<RegisterBloc, RegisterState>(
          builder: (context, state) {
            if (state is RegisterDniLookingUp) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'DNI is required';
        if (v.length != 8) return 'DNI must be 8 digits';
        return null;
      },
    );
  }
}
