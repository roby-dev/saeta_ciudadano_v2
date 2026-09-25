import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class HttpClient {
  HttpClient._();

  static Dio create({String? baseUrl, List<Interceptor> interceptors = const []}) {
    final options = BaseOptions(
      baseUrl: baseUrl ?? AppConstants.baseUrlSaeta,
      connectTimeout:
          const Duration(seconds: AppConstants.connectTimeout),
      receiveTimeout:
          const Duration(seconds: AppConstants.readTimeout),
      sendTimeout:
          const Duration(seconds: AppConstants.writeTimeout),
      headers: {'Content-Type': 'application/json'},
    );

    final dio = Dio(options);

    if (const bool.fromEnvironment('dart.vm.product') == false) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }

    dio.interceptors.addAll(interceptors);

    return dio;
  }
}
