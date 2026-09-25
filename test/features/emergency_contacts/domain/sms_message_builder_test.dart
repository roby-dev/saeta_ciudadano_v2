import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_message_builder.dart';

void main() {
  const builder = SmsMessageBuilder();

  test('builds the legacy-parity message with type name and location link',
      () {
    final body = builder.buildBody(
      alertTypeName: 'Robo',
      latitude: -12.046374,
      longitude: -77.042793,
    );

    expect(
      body,
      'Hola, tengo o acabo de presenciar un incidente del tipo Robo, '
      'por favor mantente alerta. '
      'Mi ubicación: https://maps.google.com/?q=-12.046374,-77.042793',
    );
  });

  test('interpolates a different alert type name', () {
    final body = builder.buildBody(
      alertTypeName: 'Incendio',
      latitude: 1.0,
      longitude: 2.0,
    );

    expect(body, contains('incidente del tipo Incendio,'));
    expect(body, contains('https://maps.google.com/?q=1.0,2.0'));
  });
}
