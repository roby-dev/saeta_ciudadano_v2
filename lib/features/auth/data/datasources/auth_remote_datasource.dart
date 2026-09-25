import 'package:dio/dio.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<LoginResponseModel> login(LoginRequestModel request);
  Future<String> renewToken(String refreshToken);
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
}
