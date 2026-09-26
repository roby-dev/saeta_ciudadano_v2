import 'package:dio/dio.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<LoginResponseModel> login(LoginRequestModel request);
  Future<String> renewToken(String refreshToken);

  /// Validates the stored session and returns the current user profile.
  /// Called through the app's normal [Dio] (with `AuthInterceptor`
  /// attached), so an expired access token is refreshed transparently
  /// before this ever surfaces as a failure.
  Future<UserModel> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<LoginResponseModel> login(LoginRequestModel request) async {
    final response = await _dio.post(
      '/v1/auth/login',
      data: request.toJson(),
    );
    return LoginResponseModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  @override
  Future<String> renewToken(String refreshToken) async {
    final response = await _dio.post(
      '/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['accessToken'] ?? data['token']) as String? ?? '';
  }

  @override
  Future<UserModel> getCurrentUser() async {
    // The Authorization header is attached by AuthInterceptor, which also
    // transparently refreshes an expired access token on a 401 here.
    final response = await _dio.get('/v1/auth/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}
