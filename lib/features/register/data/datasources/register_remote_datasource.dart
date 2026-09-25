import 'package:dio/dio.dart';
import '../models/person_model.dart';
import '../models/register_request_model.dart';
import '../models/register_response_model.dart';

abstract interface class RegisterRemoteDataSource {
  /// Looks up DNI via the Saeta backend proxy (which calls RENIEC internally).
  Future<PersonModel> lookupDni(String dni);

  /// Registers a new citizen user.
  Future<RegisterResponseModel> register(RegisterRequestModel request);
}

class RegisterRemoteDataSourceImpl implements RegisterRemoteDataSource {
  const RegisterRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<PersonModel> lookupDni(String dni) async {
    final response = await _dio.get('/v1/users/dni/$dni');
    return PersonModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RegisterResponseModel> register(RegisterRequestModel request) async {
    final response = await _dio.post(
      '/v1/users',
      data: request.toJson(),
    );
    return RegisterResponseModel.fromJson(
        response.data as Map<String, dynamic>);
  }
}
