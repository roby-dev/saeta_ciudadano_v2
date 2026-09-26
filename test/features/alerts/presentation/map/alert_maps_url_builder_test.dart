import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/map/alert_maps_url_builder.dart';

void main() {
  group('buildExternalMapsUri', () {
    test('builds a Google Maps search URI for the given coordinates', () {
      final uri = buildExternalMapsUri(-12.0464, -77.0428);

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], '-12.0464,-77.0428');
    });
  });
}
