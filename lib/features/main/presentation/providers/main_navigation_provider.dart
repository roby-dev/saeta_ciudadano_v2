import 'package:flutter/material.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/domain/entities/user_entity.dart';

class MainNavigationProvider extends ChangeNotifier {
  MainNavigationProvider({
    required SecureStorage storage,
    UserEntity? initialUser,
  })  : _storage = storage,
        _currentUser = initialUser;

  final SecureStorage _storage;

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

    _isLoggingOut = false;
    _currentUser = null;
    notifyListeners();
  }
}
