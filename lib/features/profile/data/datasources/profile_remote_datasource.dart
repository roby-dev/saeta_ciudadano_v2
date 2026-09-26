import 'package:dio/dio.dart';
import '../../../auth/data/models/user_model.dart';

abstract interface class ProfileRemoteDataSource {
  /// Updates the current user's own profile via `PATCH /v1/users/:id`,
  /// sending exactly `{name, lastname, phone, email}` — never `role` or
  /// `statusAccount`. Parses the response's `user` object.
  Future<UserModel> updateProfile({
    required String userId,
    required String name,
    required String lastname,
    required String phone,
    required String email,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<UserModel> updateProfile({
    required String userId,
    required String name,
    required String lastname,
    required String phone,
    required String email,
  }) async {
    // The Authorization header is attached by AuthInterceptor.
    final response = await _dio.patch<Map<String, dynamic>>(
      '/v1/users/$userId',
      data: {
        'name': name,
        'lastname': lastname,
        'phone': phone,
        'email': email,
      },
    );
    final data = response.data ?? <String, dynamic>{};
    final userJson = data['user'] as Map<String, dynamic>? ?? {};
    return UserModel.fromJson(userJson);
  }
}
