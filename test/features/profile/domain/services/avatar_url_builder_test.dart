import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/core/constants/app_constants.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_url_builder.dart';

void main() {
  group('build', () {
    test('returns null for an empty image id (no avatar yet)', () {
      const builder = AvatarUrlBuilder(baseUrl: 'https://api.example.com');
      expect(builder.build(''), isNull);
    });

    test('builds the GET /v1/uploads/:photo URL for a non-empty image id',
        () {
      const builder = AvatarUrlBuilder(baseUrl: 'https://api.example.com');
      expect(
        builder.build('abc-123.jpg'),
        'https://api.example.com/v1/uploads/abc-123.jpg',
      );
    });

    test('defaults to AppConstants.baseUrlSaeta', () {
      const builder = AvatarUrlBuilder();
      expect(builder.build('abc.jpg'), startsWith(AppConstants.baseUrlSaeta));
      expect(builder.build('abc.jpg'), endsWith('/v1/uploads/abc.jpg'));
    });
  });
}
