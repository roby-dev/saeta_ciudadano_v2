import 'package:dio/dio.dart';
import '../models/alert_model.dart';
import '../models/alert_type_model.dart';

abstract interface class EmergencyRemoteDataSource {
  Future<List<AlertTypeModel>> getAlertTypes();

  Future<AlertModel> sendAlert({
    required double latitude,
    required double longitude,
    required String typeId,
  });
}

class EmergencyRemoteDataSourceImpl implements EmergencyRemoteDataSource {
  const EmergencyRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<AlertTypeModel>> getAlertTypes() async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.get('/v1/types');

    final data = response.data as Map<String, dynamic>;
    final list = data['types'] as List<dynamic>? ?? [];
    return list
        .map((e) => AlertTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AlertModel> sendAlert({
    required double latitude,
    required double longitude,
    required String typeId,
  }) async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.post(
      '/v1/alerts',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        'type': typeId,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final alertMap = (data['alerts'] ?? data['alert'] ?? data) as Map<String, dynamic>;
    return AlertModel.fromJson(alertMap);
  }
}
