import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/auth/data/datasources/auth_remote_datasource.dart';

import '../../../core/network/fake_http_client_adapter.dart';

/// `getCurrentUser()` is the T6 auto-login validation call. `login`/
/// `renewToken` are untested here, consistent with this datasource's
/// pre-existing (T1) convention of no dedicated coverage for them.
void main() {
  late Dio dio;
  late FakeHttpClientAdapter adapter;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dataSource = AuthRemoteDataSourceImpl(dio);
  });

  test('GETs /v1/auth/me and parses the current user', () async {
    adapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {
        'id': 'u1',
        'name': 'Ana',
        'lastname': 'Lopez',
        'dni': '12345678',
        'phone': '987654321',
        'email': 'ana@test.com',
        'role': 'CIUDADANO',
        'statusAccount': 'HABILITADO',
        'image': '',
      }),
    );
    dio.httpClientAdapter = adapter;

    final user = await dataSource.getCurrentUser();

    expect(adapter.requests.single.path, '/v1/auth/me');
    expect(adapter.requests.single.method, 'GET');
    expect(user.id, 'u1');
    expect(user.name, 'Ana');
    expect(user.email, 'ana@test.com');
    expect(user.stateAccount, 'HABILITADO');
  });
}
