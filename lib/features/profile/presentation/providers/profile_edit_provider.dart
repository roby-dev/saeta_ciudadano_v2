import 'package:flutter/foundation.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import '../../domain/usecases/update_profile_usecase.dart';

/// Manages the "edit my profile" form (name, lastname, phone, email — DNI is
/// read-only) and its save flow against `PATCH /v1/users/:id`.
class ProfileEditProvider extends ChangeNotifier {
  ProfileEditProvider({
    required UpdateProfileUseCase updateProfileUseCase,
    required PeruvianPhoneNormalizer phoneNormalizer,
    required UserEntity currentUser,
    void Function(UserEntity updatedUser)? onUpdated,
  })  : _updateProfileUseCase = updateProfileUseCase,
        _phoneNormalizer = phoneNormalizer,
        _currentUser = currentUser,
        _onUpdated = onUpdated;

  final UpdateProfileUseCase _updateProfileUseCase;
  final PeruvianPhoneNormalizer _phoneNormalizer;
  final void Function(UserEntity updatedUser)? _onUpdated;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  UserEntity _currentUser;
  bool _isSaving = false;
  String? _errorMessage;

  UserEntity get currentUser => _currentUser;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  /// Per-field validators, meant to be used directly as a `TextFormField`'s
  /// `validator` so each field shows its own message.
  String? validateName(String value) {
    return value.trim().isEmpty ? 'Este campo es obligatorio' : null;
  }

  String? validatePhone(String value) {
    if (value.trim().isEmpty) return 'El teléfono es obligatorio';
    return _phoneNormalizer.normalize(value) == null
        ? 'Ingresa un número de celular peruano válido (9 dígitos)'
        : null;
  }

  String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'El correo es obligatorio';
    return _emailPattern.hasMatch(trimmed)
        ? null
        : 'Ingresa un correo electrónico válido';
  }

  /// Validates and, if valid, sends the update via `PATCH /v1/users/:id`
  /// (only `{name, lastname, phone, email}`, never `role`/`statusAccount`).
  /// On success, replaces [currentUser] and calls [onUpdated] (used by the
  /// caller to refresh `MainNavigationProvider` immediately, without waiting
  /// for the `updatedProfile` socket event). On failure, [currentUser] is
  /// left untouched and [errorMessage] carries the backend's message
  /// (including a 409 duplicate email/phone conflict).
  Future<bool> save({
    required String name,
    required String lastname,
    required String phone,
    required String email,
  }) async {
    final nameError = validateName(name);
    final lastnameError = validateName(lastname);
    final phoneError = validatePhone(phone);
    final emailError = validateEmail(email);
    final firstError = nameError ?? lastnameError ?? phoneError ?? emailError;
    if (firstError != null) {
      _errorMessage = firstError;
      notifyListeners();
      return false;
    }

    final normalizedPhone = _phoneNormalizer.normalize(phone)!;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _updateProfileUseCase(
      _currentUser.id,
      name: name.trim(),
      lastname: lastname.trim(),
      phone: normalizedPhone,
      email: email.trim(),
    );

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        return false;
      },
      (updatedUser) {
        _currentUser = updatedUser;
        _errorMessage = null;
        _onUpdated?.call(updatedUser);
        return true;
      },
    );

    _isSaving = false;
    notifyListeners();
    return success;
  }
}
