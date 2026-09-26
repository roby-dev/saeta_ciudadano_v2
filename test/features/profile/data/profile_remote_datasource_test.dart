import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/features/auth/data/models/user_model.dart';
import 'package:saeta_ciudadano_v2/features/profile/data/datasources/profile_remote_datasource.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _response(Map<String, dynamic> data) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/v1/users/u1'),
    data: data,
    statusCode: 200,
  );
}

void main() {
  late MockDio dio;
  late ProfileRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = ProfileRemoteDataSourceImpl(dio: dio);
  });

  group('updateProfile', () {
    test('PATCHes /v1/users/:id with exactly name, lastname, phone and '
        'email, and parses the returned user', () async {
      when(() => dio.patch<Map<String, dynamic>>(
            '/v1/users/u1',
            data: {
              'name': 'Ana',
              'lastname': 'Torres',
              'phone': '987654321',
              'email': 'ana@example.com',
            },
          )).thenAnswer(
        (_) async => _response({
          'ok': true,
          'user': {
            'id': 'u1',
            'name': 'Ana',
            'lastname': 'Torres',
            'dni': '12345678',
            'phone': '987654321',
            'email': 'ana@example.com',
          },
        }),
      );

      final result = await dataSource.updateProfile(
        userId: 'u1',
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      expect(result, isA<UserModel>());
      expect(result.id, 'u1');
      expect(result.name, 'Ana');
      expect(result.lastname, 'Torres');
      expect(result.dni, '12345678');
      expect(result.phone, '987654321');
      expect(result.email, 'ana@example.com');
      verify(() => dio.patch<Map<String, dynamic>>(
            '/v1/users/u1',
            data: {
              'name': 'Ana',
              'lastname': 'Torres',
              'phone': '987654321',
              'email': 'ana@example.com',
            },
          )).called(1);
    });

    test('never sends role or statusAccount in the request body', () async {
      when(() => dio.patch<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer(
        (_) async => _response({
          'ok': true,
          'user': {'id': 'u1'},
        }),
      );

      await dataSource.updateProfile(
        userId: 'u1',
        name: 'Ana',
        lastname: 'Torres',
        phone: '987654321',
        email: 'ana@example.com',
      );

      final captured = verify(() => dio.patch<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
          )).captured.single as Map<String, dynamic>;
      expect(captured.containsKey('role'), isFalse);
      expect(captured.containsKey('statusAccount'), isFalse);
    });
  });
}
