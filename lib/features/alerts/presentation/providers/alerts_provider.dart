import 'package:flutter/foundation.dart';
import '../../domain/entities/citizen_alert_entity.dart';
import '../../domain/usecases/get_user_alerts_usecase.dart';
import '../../domain/usecases/send_alert_feedback_usecase.dart';

class AlertsProvider extends ChangeNotifier {
  AlertsProvider({
    required GetUserAlertsUseCase getUserAlertsUseCase,
    required SendAlertFeedbackUseCase sendAlertFeedbackUseCase,
  })  : _getUserAlertsUseCase = getUserAlertsUseCase,
        _sendAlertFeedbackUseCase = sendAlertFeedbackUseCase;

  final GetUserAlertsUseCase _getUserAlertsUseCase;
  final SendAlertFeedbackUseCase _sendAlertFeedbackUseCase;

  List<CitizenAlertEntity> _alerts = [];
  bool _isLoading = false;
  bool _isSubmittingFeedback = false;
  String? _errorMessage;
  String? _lastLoadedUserId;

  List<CitizenAlertEntity> get alerts => _alerts;
  bool get isLoading => _isLoading;
  bool get isSubmittingFeedback => _isSubmittingFeedback;
  String? get errorMessage => _errorMessage;

  Future<void> loadAlerts(String userId, {bool showLoading = true}) async {
    _lastLoadedUserId = userId;
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final result = await _getUserAlertsUseCase(userId);
    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isLoading = false;
        notifyListeners();
      },
      (list) {
        // Sort alerts by newest first
        list.sort((a, b) => b.creationDate.compareTo(a.creationDate));
        _alerts = list;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  Future<void> refreshAlerts() async {
    if (_lastLoadedUserId != null && _lastLoadedUserId!.isNotEmpty) {
      await loadAlerts(_lastLoadedUserId!, showLoading: false);
    }
  }

  Future<bool> submitFeedback({
    required String alertId,
    required String commentary,
    required double score,
  }) async {
    _isSubmittingFeedback = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _sendAlertFeedbackUseCase(
      alertId: alertId,
      commentary: commentary,
      score: score,
    );

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        _isSubmittingFeedback = false;
        notifyListeners();
        return false;
      },
      (updatedAlert) {
        final index = _alerts.indexWhere((a) => a.id == alertId);
        if (index != -1) {
          _alerts[index] = updatedAlert;
        }
        _isSubmittingFeedback = false;
        notifyListeners();
        return true;
      },
    );
  }
}
