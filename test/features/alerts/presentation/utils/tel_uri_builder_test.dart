import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/utils/tel_uri_builder.dart';

void main() {
  test('TelUriBuilder builds a tel: uri for the given phone number', () {
    const builder = TelUriBuilder();

    final uri = builder.build('987654321');

    expect(uri.scheme, 'tel');
    expect(uri.path, '987654321');
  });
}
