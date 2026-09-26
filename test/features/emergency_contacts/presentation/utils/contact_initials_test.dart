import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/presentation/utils/contact_initials.dart';

void main() {
  group('contactInitials', () {
    test('returns the first letter of the first 2 words, uppercased', () {
      expect(contactInitials('Ana Lopez'), 'AL');
    });

    test('returns a single letter for a one-word name', () {
      expect(contactInitials('Ana'), 'A');
    });

    test('returns "?" for an empty/whitespace-only name', () {
      expect(contactInitials(''), '?');
      expect(contactInitials('   '), '?');
    });
  });
}
