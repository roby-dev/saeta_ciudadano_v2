import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';

void main() {
  const normalizer = PeruvianPhoneNormalizer();

  group('normalize', () {
    for (final input in <String>[
      '987654321',
      '987 654 321',
      '987-654-321',
      '+51 987 654 321',
      '+51987654321',
      '51987654321',
      '(+51) 987-654-321',
    ]) {
      test('normalizes "$input" to "987654321"', () {
        expect(normalizer.normalize(input), '987654321');
      });
    }

    for (final input in <String>[
      '98765432', // 8 digits, too short
      '9876543210', // 10 digits, too long
      '+1 987 654 321', // non-Peruvian country code
      'abc',
      '',
    ]) {
      test('rejects "$input" (returns null)', () {
        expect(normalizer.normalize(input), isNull);
      });
    }
  });
}
