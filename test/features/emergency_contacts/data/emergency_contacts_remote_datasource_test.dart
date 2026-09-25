import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/data/datasources/emergency_contacts_remote_datasource.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/data/models/emergency_contact_model.dart';

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
  late EmergencyContactsRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = EmergencyContactsRemoteDataSourceImpl(dio: dio);
  });

  group('getContacts', () {
    test('GETs /v1/users/:id and parses the emergencyContacts list',
        () async {
      when(() => dio.get<Map<String, dynamic>>('/v1/users/u1')).thenAnswer(
        (_) async => _response({
          'ok': true,
          'user': {
            'id': 'u1',
            'emergencyContacts': [
              {'name': 'Ana', 'phone': '987654321'},
              {'name': 'Luis', 'phone': '912345678'},
            ],
          },
        }),
      );

      final result = await dataSource.getContacts('u1');

      expect(result, [
        const EmergencyContactModel(name: 'Ana', phone: '987654321'),
        const EmergencyContactModel(name: 'Luis', phone: '912345678'),
      ]);
      verify(() => dio.get<Map<String, dynamic>>('/v1/users/u1')).called(1);
    });

    test('returns an empty list when the user has no emergencyContacts',
        () async {
      when(() => dio.get<Map<String, dynamic>>('/v1/users/u1')).thenAnswer(
        (_) async => _response({
          'ok': true,
          'user': {'id': 'u1'},
        }),
      );

      final result = await dataSource.getContacts('u1');

      expect(result, isEmpty);
    });
  });

  group('saveContacts', () {
    test('PATCHes /v1/users/:id with the full contacts list and parses '
        'the response', () async {
      when(() => dio.patch<Map<String, dynamic>>(
            '/v1/users/u1',
            data: {
              'emergencyContacts': [
                {'name': 'Ana', 'phone': '987654321'},
              ],
            },
          )).thenAnswer(
        (_) async => _response({
          'ok': true,
          'user': {
            'id': 'u1',
            'emergencyContacts': [
              {'name': 'Ana', 'phone': '987654321'},
            ],
          },
        }),
      );

      final result = await dataSource.saveContacts(
        'u1',
        const [EmergencyContactModel(name: 'Ana', phone: '987654321')],
      );

      expect(result, [
        const EmergencyContactModel(name: 'Ana', phone: '987654321'),
      ]);
    });
  });
}
