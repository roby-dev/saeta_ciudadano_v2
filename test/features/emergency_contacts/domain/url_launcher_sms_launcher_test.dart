import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/sms_launcher.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/url_launcher_sms_launcher.dart';

void main() {
  test('launches the sms: uri built from phone numbers and body', () async {
    Uri? capturedUri;
    final launcher = UrlLauncherSmsLauncher(
      launch: (uri) async {
        capturedUri = uri;
        return true;
      },
    );

    await launcher.launch(
      phoneNumbers: ['987654321', '912345678'],
      body: 'Hola',
    );

    expect(capturedUri?.scheme, 'sms');
    expect(capturedUri?.path, '987654321,912345678');
    expect(capturedUri?.queryParameters['body'], 'Hola');
  });

  test('throws SmsLaunchException when the platform reports it could not '
      'open the composer', () async {
    final launcher = UrlLauncherSmsLauncher(launch: (_) async => false);

    expect(
      () => launcher.launch(phoneNumbers: ['987654321'], body: 'Hola'),
      throwsA(isA<SmsLaunchException>()),
    );
  });
}
