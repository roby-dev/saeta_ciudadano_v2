import 'package:dio/dio.dart';
import '../models/citizen_alert_model.dart';

abstract interface class AlertsRemoteDataSource {
  Future<List<CitizenAlertModel>> getUserAlerts(String userId);

  Future<CitizenAlertModel> sendAlertFeedback({
    required String alertId,
    required String commentary,
    required double score,
  });
}

class AlertsRemoteDataSourceImpl implements AlertsRemoteDataSource {
  const AlertsRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<CitizenAlertModel>> getUserAlerts(String userId) async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.get('/v1/alerts/user/$userId');

    final data = response.data as Map<String, dynamic>;
    final list = data['alerts'] as List<dynamic>? ?? [];
    return list
        .map((e) => CitizenAlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CitizenAlertModel> sendAlertFeedback({
    required String alertId,
    required String commentary,
    required double score,
  }) async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.put(
      '/v1/alerts/commentary/$alertId',
      data: {
        'commentary': commentary,
        'score': score.round(),
      },
    );

    final data = response.data as Map<String, dynamic>;
    final alertMap = (data['alerts'] ?? data['alert'] ?? data) as Map<String, dynamic>;
    return CitizenAlertModel.fromJson(alertMap);
  }
}
