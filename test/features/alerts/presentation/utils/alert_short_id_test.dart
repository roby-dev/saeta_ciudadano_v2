import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/utils/alert_short_id.dart';

void main() {
  group('alertShortId', () {
    test('returns the last 6 characters uppercased for a longer id', () {
      expect(alertShortId('68d9f2a1c4e7b0331245abcd'), '45ABCD');
      expect(alertShortId('abcdef123456'), '123456');
    });

    test('returns the whole id uppercased when it is 6 characters or '
        'shorter', () {
      expect(alertShortId('a1b2'), 'A1B2');
      expect(alertShortId('abcdef'), 'ABCDEF');
    });

    test('returns null for an empty id', () {
      expect(alertShortId(''), isNull);
    });
  });
}
