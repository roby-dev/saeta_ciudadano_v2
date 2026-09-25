import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/entities/alert_type_entity.dart';
import '../../domain/usecases/get_alert_types_usecase.dart';
import '../../domain/usecases/send_alert_usecase.dart';

class EmergencyProvider extends ChangeNotifier {
  EmergencyProvider({
    required GetAlertTypesUseCase getAlertTypesUseCase,
    required SendAlertUseCase sendAlertUseCase,
  })  : _getAlertTypesUseCase = getAlertTypesUseCase,
        _sendAlertUseCase = sendAlertUseCase {
    loadAlertTypes();
  }

  final GetAlertTypesUseCase _getAlertTypesUseCase;
  final SendAlertUseCase _sendAlertUseCase;

  List<AlertTypeEntity> _alertTypes = [];
  bool _isLoadingTypes = false;
  bool _isSendingAlert = false;
  String? _errorMessage;
  AlertEntity? _lastSentAlert;

  List<AlertTypeEntity> get alertTypes => _alertTypes;
  bool get isLoadingTypes => _isLoadingTypes;
  bool get isSendingAlert => _isSendingAlert;
  String? get errorMessage => _errorMessage;
  AlertEntity? get lastSentAlert => _lastSentAlert;

  Future<void> loadAlertTypes() async {
    _isLoadingTypes = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _getAlertTypesUseCase();
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoadingTypes = false;
        notifyListeners();
      },
      (types) {
        _alertTypes = types;
        _isLoadingTypes = false;
        notifyListeners();
      },
    );
  }

  Future<Position> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallbackPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _fallbackPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _fallbackPosition();
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return _fallbackPosition();
    }
  }

  Position _fallbackPosition() {
    return Position(
      latitude: -12.046374,
      longitude: -77.042793,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  /// Finds type ID by matching standard alert type names
  String? findTypeIdByName(String targetName) {
    if (_alertTypes.isEmpty) return null;

    final normalized = targetName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    for (final t in _alertTypes) {
      final tName = t.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (tName == normalized || tName.contains(normalized) || normalized.contains(tName)) {
        return t.id;
      }
    }
    // Fallback: return the first type available
    return _alertTypes.first.id;
  }

  Future<bool> sendAlert(String typeName) async {
    _isSendingAlert = true;
    _errorMessage = null;
    notifyListeners();

    if (_alertTypes.isEmpty) {
      await loadAlertTypes();
    }

    final typeId = findTypeIdByName(typeName) ?? (_alertTypes.isNotEmpty ? _alertTypes.first.id : '');

    if (typeId.isEmpty) {
      _errorMessage = 'No se encontraron tipos de alerta configurados en el servidor';
      _isSendingAlert = false;
      notifyListeners();
      return false;
    }

    final position = await _determinePosition();

    final result = await _sendAlertUseCase(
      latitude: position.latitude,
      longitude: position.longitude,
      typeId: typeId,
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isSendingAlert = false;
        notifyListeners();
        return false;
      },
      (alert) {
        _lastSentAlert = alert;
        _isSendingAlert = false;
        notifyListeners();
        return true;
      },
    );
  }
}
