import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/map/alert_map_coordinates.dart';

void main() {
  group('alertMapCoordinates', () {
    test('valid coordinates return a LatLng', () {
      final result = alertMapCoordinates(-12.0464, -77.0428);
      expect(result, const LatLng(-12.0464, -77.0428));
    });

    test('(0, 0) is treated as the missing-coordinate sentinel and is invalid', () {
      // CitizenAlertModel.fromJson defaults a missing latitude/longitude to
      // 0.0, so (0, 0) can never be a real reported position for this app.
      expect(alertMapCoordinates(0, 0), isNull);
    });

    test('NaN latitude or longitude is invalid', () {
      expect(alertMapCoordinates(double.nan, -77.0428), isNull);
      expect(alertMapCoordinates(-12.0464, double.nan), isNull);
    });

    test('out-of-range latitude is invalid', () {
      expect(alertMapCoordinates(-91, -77.0428), isNull);
      expect(alertMapCoordinates(91, -77.0428), isNull);
    });

    test('out-of-range longitude is invalid', () {
      expect(alertMapCoordinates(-12.0464, -181), isNull);
      expect(alertMapCoordinates(-12.0464, 181), isNull);
    });

    test('boundary values are valid', () {
      expect(alertMapCoordinates(90, 180), const LatLng(90, 180));
      expect(alertMapCoordinates(-90, -180), const LatLng(-90, -180));
    });

    test('a non-zero coordinate with one axis at 0 is valid', () {
      // Only the exact (0, 0) pair is the sentinel; a real position can
      // legitimately sit on the equator or the prime meridian alone.
      expect(alertMapCoordinates(0, -77.0428), const LatLng(0, -77.0428));
      expect(alertMapCoordinates(-12.0464, 0), const LatLng(-12.0464, 0));
    });
  });
}
