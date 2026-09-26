import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/models/emergency_contact_model.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../../domain/services/device_contact_picker.dart';
import '../../domain/services/peruvian_phone_normalizer.dart';
import '../../domain/services/sms_launcher.dart';
import '../../domain/services/sms_message_builder.dart';
import '../../domain/usecases/get_emergency_contacts_usecase.dart';
import '../../domain/usecases/save_emergency_contacts_usecase.dart';

/// Manages the current user's emergency contacts (max [maxContacts], backed
/// by `PATCH`/`GET /v1/users/:id`) and the local "send SMS to my emergency
/// contacts on alert" preference, and opens the SMS composer after a
/// successful alert when that preference is on and there is at least one
/// contact.
class EmergencyContactsProvider extends ChangeNotifier {
  EmergencyContactsProvider({
    required GetEmergencyContactsUseCase getContactsUseCase,
    required SaveEmergencyContactsUseCase saveContactsUseCase,
    required SecureStorage storage,
    required DeviceContactPicker contactPicker,
    required SmsLauncher smsLauncher,
    required PeruvianPhoneNormalizer phoneNormalizer,
    required SmsMessageBuilder messageBuilder,
    required RealtimeService realtimeService,
  })  : _getContactsUseCase = getContactsUseCase,
        _saveContactsUseCase = saveContactsUseCase,
        _storage = storage,
        _contactPicker = contactPicker,
        _smsLauncher = smsLauncher,
        _phoneNormalizer = phoneNormalizer,
        _messageBuilder = messageBuilder {
    // Live profile sync: a socket `updatedProfile` event for this user
    // replaces the contact list without a REST round-trip (see
    // _handleUpdatedProfile for the exact rules).
    _profileSubscription =
        realtimeService.updatedProfiles.listen(_handleUpdatedProfile);
  }

  static const int maxContacts = 5;

  final GetEmergencyContactsUseCase _getContactsUseCase;
  final SaveEmergencyContactsUseCase _saveContactsUseCase;
  final SecureStorage _storage;
  final DeviceContactPicker _contactPicker;
  final SmsLauncher _smsLauncher;
  final PeruvianPhoneNormalizer _phoneNormalizer;
  final SmsMessageBuilder _messageBuilder;
  late final StreamSubscription<Map<String, dynamic>> _profileSubscription;

  String? _userId;
  List<EmergencyContactEntity> _contacts = [];
  bool _sendSmsOnAlert = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<EmergencyContactEntity> get contacts => _contacts;

  /// Always false when there are no contacts, regardless of the stored
  /// value — mirrors the legacy app forcing the switch off in that case.
  bool get sendSmsOnAlert => _contacts.isEmpty ? false : _sendSmsOnAlert;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get canAddContact => _contacts.length < maxContacts;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _userId = await _storage.getUserId();
    _sendSmsOnAlert = await _storage.getSendSmsOnAlert();

    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _errorMessage = 'No se pudo identificar al usuario actual';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final result = await _getContactsUseCase(userId);
    await result.fold(
      (failure) async {
        _errorMessage = failure.message;
      },
      (contacts) async {
        _contacts = contacts;
        await _enforcePreferenceInvariant();
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Forces the sms-on-alert preference off (and persists it) whenever
  /// there are no contacts left.
  Future<void> _enforcePreferenceInvariant() async {
    if (_contacts.isEmpty && _sendSmsOnAlert) {
      _sendSmsOnAlert = false;
      await _storage.setSendSmsOnAlert(false);
    }
  }

  Future<void> setSendSmsOnAlert(bool value) async {
    final effective = _contacts.isEmpty ? false : value;
    _sendSmsOnAlert = effective;
    await _storage.setSendSmsOnAlert(effective);
    notifyListeners();
  }

  /// Opens the device contact picker and, if a contact was picked with a
  /// phone number that normalizes to a valid Peruvian mobile number and
  /// isn't already added, saves the updated list to the backend.
  ///
  /// Returns `true` on success. Returns `false` both on cancellation (no
  /// [errorMessage] set) and on validation/save failure ([errorMessage]
  /// set).
  Future<bool> addContactFromPicker() async {
    _errorMessage = null;

    if (!canAddContact) {
      _errorMessage =
          'Ya alcanzaste el máximo de $maxContacts contactos de emergencia';
      notifyListeners();
      return false;
    }

    final picked = await _contactPicker.pickContactPhoneNumber();
    if (picked == null) {
      // User cancelled the picker: not an error.
      return false;
    }

    final normalizedPhone = _phoneNormalizer.normalize(picked.phoneNumber);
    if (normalizedPhone == null) {
      _errorMessage = 'No se pudo validar el número de teléfono del '
          'contacto seleccionado';
      notifyListeners();
      return false;
    }

    if (_contacts.any((c) => c.phone == normalizedPhone)) {
      _errorMessage = 'Ese contacto ya fue agregado';
      notifyListeners();
      return false;
    }

    final updated = [
      ..._contacts,
      EmergencyContactEntity(name: picked.name, phone: normalizedPhone),
    ];
    return _persist(updated);
  }

  Future<bool> removeContact(EmergencyContactEntity contact) async {
    final updated = _contacts.where((c) => c != contact).toList();
    final success = await _persist(updated);
    if (success && _contacts.isEmpty) {
      await setSendSmsOnAlert(false);
    }
    return success;
  }

  Future<bool> _persist(List<EmergencyContactEntity> updated) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _errorMessage = 'No se pudo identificar al usuario actual';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    notifyListeners();

    final result = await _saveContactsUseCase(userId, updated);
    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        return false;
      },
      (contacts) {
        _contacts = contacts;
        _errorMessage = null;
        return true;
      },
    );

    _isSaving = false;
    notifyListeners();
    return success;
  }

  /// Opens the SMS composer for all current emergency contacts when the
  /// preference is on and there is at least one contact. Never throws: a
  /// launch failure must never affect the (already successful) alert flow
  /// that triggered this call.
  Future<void> sendSmsForAlert({
    required String alertTypeName,
    required double latitude,
    required double longitude,
  }) async {
    if (!sendSmsOnAlert || _contacts.isEmpty) return;

    try {
      final body = _messageBuilder.buildBody(
        alertTypeName: alertTypeName,
        latitude: latitude,
        longitude: longitude,
      );
      final phoneNumbers = _contacts.map((c) => c.phone).toList();
      await _smsLauncher.launch(phoneNumbers: phoneNumbers, body: body);
    } catch (error) {
      debugPrint('EmergencyContactsProvider: failed to open SMS composer: '
          '$error');
    }
  }

  /// Reacts to a live `updatedProfile` socket event: replaces the contact
  /// list from the payload's `emergencyContacts` field, without a REST
  /// call, when the payload is for this user.
  ///
  /// The `emergencyContacts` key is only present on the payload when it's
  /// part of what changed server-side (see `RealtimeService.updatedProfiles`
  /// docs), so its absence means "unrelated profile change" and the current
  /// list is left untouched rather than wiped. An id that doesn't match the
  /// loaded [_userId] is ignored the same way.
  void _handleUpdatedProfile(Map<String, dynamic> payload) {
    final id = payload['id'] as String? ?? payload['_id'] as String?;
    if (id == null || id != _userId) return;
    if (!payload.containsKey('emergencyContacts')) return;

    final rawContacts = payload['emergencyContacts'];
    _contacts = rawContacts is List
        ? rawContacts
            .whereType<Map>()
            .map((contact) => EmergencyContactModel.fromJson(
                  Map<String, dynamic>.from(contact),
                ).toEntity())
            .toList()
        : <EmergencyContactEntity>[];

    // Fire-and-forget: the sendSmsOnAlert getter already reflects the
    // forced-off state from _contacts.isEmpty immediately; this just
    // persists it, same convention as the rest of this class's use of
    // _enforcePreferenceInvariant().
    unawaited(_enforcePreferenceInvariant());
    notifyListeners();
  }

  @override
  void dispose() {
    _profileSubscription.cancel();
    super.dispose();
  }
}
