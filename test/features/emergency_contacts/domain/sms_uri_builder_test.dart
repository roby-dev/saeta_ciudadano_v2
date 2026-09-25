import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_uri_builder.dart';

void main() {
  const builder = SmsUriBuilder();

  test('builds an sms: uri with comma-separated recipients and the body '
      'as a query parameter', () {
    final uri = builder.build(
      phoneNumbers: ['987654321', '912345678'],
      body: 'Hola, esto es una prueba',
    );

    expect(uri.scheme, 'sms');
    expect(uri.path, '987654321,912345678');
    expect(uri.queryParameters['body'], 'Hola, esto es una prueba');
  });

  test('builds an sms: uri for a single recipient', () {
    final uri = builder.build(
      phoneNumbers: ['987654321'],
      body: 'Mensaje',
    );

    expect(uri.path, '987654321');
  });

  test('percent-encodes special characters in the body', () {
    final uri = builder.build(
      phoneNumbers: ['987654321'],
      body: 'Ubicación: https://maps.google.com/?q=-12.0,-77.0',
    );

    expect(uri.toString(), contains('sms:987654321?body='));
    expect(
      uri.queryParameters['body'],
      'Ubicación: https://maps.google.com/?q=-12.0,-77.0',
    );
  });
}
