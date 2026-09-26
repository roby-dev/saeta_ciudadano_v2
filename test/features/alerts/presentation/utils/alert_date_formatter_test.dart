import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/utils/alert_date_formatter.dart';

void main() {
  group('formatAlertDate', () {
    test('formats an ISO date as "d mmm yyyy · HH:mm" with a Spanish '
        '3-letter month abbreviation', () {
      expect(
        formatAlertDate('2026-09-26T14:32:00.000Z'),
        '26 sep 2026 · 14:32',
      );
    });

    test('pads a single-digit day, hour and minute', () {
      expect(
        formatAlertDate('2026-01-05T09:07:00.000Z'),
        '05 ene 2026 · 09:07',
      );
    });

    test('covers all 12 Spanish month abbreviations', () {
      const expected = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];
      for (var month = 1; month <= 12; month++) {
        final iso = '2026-${month.toString().padLeft(2, '0')}-01T00:00:00.000Z';
        expect(formatAlertDate(iso), contains(expected[month - 1]));
      }
    });

    test('returns the original string unchanged when it cannot be parsed',
        () {
      expect(formatAlertDate('not-a-date'), 'not-a-date');
      expect(formatAlertDate(''), '');
    });
  });
}
