import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../service_locator.dart';
import '../../../auth/domain/entities/user_entity.dart';
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
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => provider.validateName(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastnameController,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => provider.validateName(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => provider.validatePhone(value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => provider.validateEmail(value ?? ''),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: provider.isSaving ? null : _onSave,
                child: provider.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
