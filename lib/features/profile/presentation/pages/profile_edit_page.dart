import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/widgets/saeta_text_field.dart';
import '../../../emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../providers/profile_edit_provider.dart';

/// "Editar perfil" form: name, lastname, phone and email. DNI is read-only
/// and not shown here as an editable field.
///
/// [onUpdated] is resolved by the caller (`ProfileView`) from
/// `MainNavigationProvider.setUser` *before* this page is pushed, rather than
/// looked up here via `context.read`: this page is opened with
/// `Navigator.push` on the app-level Navigator (above `MainPage`'s
/// `MultiProvider`), so `MainNavigationProvider` is not an ancestor of this
/// page's own `BuildContext` and a lookup here would throw
/// `ProviderNotFoundException`.
class ProfileEditPage extends StatelessWidget {
  const ProfileEditPage({super.key, required this.user, this.onUpdated});

  final UserEntity user;
  final void Function(UserEntity updatedUser)? onUpdated;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileEditProvider>(
      create: (_) => ProfileEditProvider(
        updateProfileUseCase: sl<UpdateProfileUseCase>(),
        phoneNormalizer: sl<PeruvianPhoneNormalizer>(),
        currentUser: user,
        onUpdated: onUpdated,
      ),
      child: const _ProfileEditForm(),
    );
  }
}

class _ProfileEditForm extends StatefulWidget {
  const _ProfileEditForm();

  @override
  State<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<_ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _lastnameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final user = context.read<ProfileEditProvider>().currentUser;
    _nameController = TextEditingController(text: user.name);
    _lastnameController = TextEditingController(text: user.lastname);
    _phoneController = TextEditingController(text: user.phone);
    _emailController = TextEditingController(text: user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<ProfileEditProvider>();
    final success = await provider.save(
      name: _nameController.text,
      lastname: _lastnameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
      Navigator.of(context).pop();
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileEditProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SaetaTextField(
                  label: 'Nombre',
                  controller: _nameController,
                  validator: (value) => provider.validateName(value ?? ''),
                ),
                const SizedBox(height: 16),
                SaetaTextField(
                  label: 'Apellido',
                  controller: _lastnameController,
                  validator: (value) => provider.validateName(value ?? ''),
                ),
                const SizedBox(height: 16),
                SaetaTextField(
                  label: 'Teléfono',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) => provider.validatePhone(value ?? ''),
                ),
                const SizedBox(height: 16),
                SaetaTextField(
                  label: 'Correo electrónico',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => provider.validateEmail(value ?? ''),
                ),
                const SizedBox(height: 32),
                if (provider.isSaving)
                  FilledButton.icon(
                    onPressed: null,
                    icon: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    label: const Text('Guardando...'),
                  )
                else
                  FilledButton(
                    onPressed: _onSave,
                    child: const Text('Guardar cambios'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
