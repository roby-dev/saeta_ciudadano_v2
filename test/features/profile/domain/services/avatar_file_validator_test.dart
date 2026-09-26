import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_file_validator.dart';

void main() {
  const validator = AvatarFileValidator();

  group('validate', () {
    test('accepts an allowed extension under the 5MB limit', () {
      expect(
        validator.validate(path: '/tmp/photo.jpg', sizeBytes: 1024),
        isNull,
      );
    });

    test('accepts every allowed extension (png, jpg, jpeg, gif, webp), '
        'case-insensitively', () {
      for (final ext in ['png', 'JPG', 'jpeg', 'GIF', 'webp']) {
        expect(
          validator.validate(path: '/tmp/photo.$ext', sizeBytes: 1024),
          isNull,
          reason: 'expected .$ext to be accepted',
        );
      }
    });

    test('rejects an unsupported extension with a Spanish message', () {
      final error =
          validator.validate(path: '/tmp/document.pdf', sizeBytes: 1024);
      expect(error, isNotNull);
      expect(error, contains('PNG'));
    });

    test('rejects a file with no extension', () {
      expect(
        validator.validate(path: '/tmp/photo', sizeBytes: 1024),
        isNotNull,
      );
    });

    test('rejects a file over 5MB even with an allowed extension', () {
      final error = validator.validate(
        path: '/tmp/photo.png',
        sizeBytes: 5 * 1024 * 1024 + 1,
      );
      expect(error, isNotNull);
      expect(error, contains('5 MB'));
    });

    test('accepts a file at exactly 5MB', () {
      expect(
        validator.validate(path: '/tmp/photo.png', sizeBytes: 5 * 1024 * 1024),
        isNull,
      );
    });
  });
}
