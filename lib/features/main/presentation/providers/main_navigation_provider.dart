import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';

class MainNavigationProvider extends ChangeNotifier {
  MainNavigationProvider({
    required SecureStorage storage,
    required RealtimeService realtimeService,
    UserEntity? initialUser,
  })  : _storage = storage,
        _realtimeService = realtimeService,
        _currentUser = initialUser {
    // Live profile sync: a socket `updatedProfile` event for the current
    // user re-renders the profile view without a REST round-trip.
    // Mismatched id (someone else's profile, impossible in practice since
    // the server only ever broadcasts to `user:{id}`, but checked
    // defensively) or no current user yet are both ignored.
    _profileSubscription =
        _realtimeService.updatedProfiles.listen(_handleUpdatedProfile);
  }

  final SecureStorage _storage;
  final RealtimeService _realtimeService;
  late final StreamSubscription<Map<String, dynamic>> _profileSubscription;

  int _currentIndex = 0;
  UserEntity? _currentUser;
  bool _isLoggingOut = false;

  int get currentIndex => _currentIndex;
  UserEntity? get currentUser => _currentUser;
  bool get isLoggingOut => _isLoggingOut;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void setUser(UserEntity user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggingOut = true;
    notifyListeners();

    await _storage.clearSession();
    await _realtimeService.disconnect();

    _isLoggingOut = false;
    _currentUser = null;
    notifyListeners();
  }

  /// Reacts to a live `updatedProfile` socket event: replaces [currentUser]
  /// with the payload's data when it's for this user, so the profile view
  /// re-renders without a REST refetch.
  ///
  /// Parsing decision: the payload is merged onto the *current* user's
  /// existing fields (payload keys win, missing keys keep their current
  /// value) rather than parsed standalone through `UserModel.fromJson`. The
  /// backend's sanitized payload only carries a field when it's not
  /// `undefined` server-side (e.g. `averageScore` before the user has ever
  /// been scored is dropped entirely by JSON serialization, not sent as
  /// `null`/`0`); parsing it alone would let `UserModel.fromJson`'s
  /// fallback defaults silently blank an existing value back to `''`/`0`.
  /// `UserModel.fromJson` itself already accepts both the REST (`id`,
  /// `statusAccount`) and this socket payload's key names, so it's reused
  /// as-is rather than duplicated.
  void _handleUpdatedProfile(Map<String, dynamic> payload) {
    final user = _currentUser;
    if (user == null) return;

    final id = payload['id'] as String? ?? payload['_id'] as String?;
    if (id == null || id != user.id) return;

    final merged = <String, dynamic>{
      'id': user.id,
      'name': user.name,
      'lastname': user.lastname,
      'dni': user.dni,
      'phone': user.phone,
      'email': user.email,
      'image': user.image,
      'role': user.role,
      'statusAccount': user.stateAccount,
      'averageScore': user.averageScore,
      'alertsAttended': user.alertsAttended,
      ...payload,
    };
    setUser(UserModel.fromJson(merged).toEntity());
  }

  @override
  void dispose() {
    _profileSubscription.cancel();
    super.dispose();
  }
}
