import 'package:dio/dio.dart';
import '../models/emergency_contact_model.dart';

abstract interface class EmergencyContactsRemoteDataSource {
  /// Reads the current user's emergency contacts from `GET /v1/users/:id`.
  Future<List<EmergencyContactModel>> getContacts(String userId);

  /// Replaces the current user's full emergency contacts list via
  /// `PATCH /v1/users/:id`. The backend enforces the max-5 rule and phone
  /// normalization/validation server-side too.
  Future<List<EmergencyContactModel>> saveContacts(
    String userId,
    List<EmergencyContactModel> contacts,
  );
}

class EmergencyContactsRemoteDataSourceImpl
    implements EmergencyContactsRemoteDataSource {
  const EmergencyContactsRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  List<EmergencyContactModel> _parseContacts(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final list = user['emergencyContacts'] as List<dynamic>? ?? [];
    return list
        .map((e) => EmergencyContactModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<EmergencyContactModel>> getContacts(String userId) async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.get<Map<String, dynamic>>('/v1/users/$userId');
    return _parseContacts(response.data ?? <String, dynamic>{});
  }

  @override
  Future<List<EmergencyContactModel>> saveContacts(
    String userId,
    List<EmergencyContactModel> contacts,
  ) async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.patch<Map<String, dynamic>>(
      '/v1/users/$userId',
      data: {
        'emergencyContacts': contacts.map((c) => c.toJson()).toList(),
      },
    );
    return _parseContacts(response.data ?? <String, dynamic>{});
  }
}
