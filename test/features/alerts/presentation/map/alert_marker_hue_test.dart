import 'package:flutter_test/flutter_test.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/map/alert_marker_hue.dart';

void main() {
  group('alertMarkerHue', () {
    // Legacy parity: hues computed from the exact hex colors in the Android
    // app's `strings.xml` (textColorState*), matching
    // `Color.colorToHSV`/`BitmapDescriptorFactory.defaultMarker(hue)`.
    test('Resuelta maps to the legacy green hue (#17E76A)', () {
      expect(alertMarkerHue('Resuelta'), closeTo(143.9423, 0.001));
    });

    test('En proceso maps to the legacy blue hue (#0029FF)', () {
      expect(alertMarkerHue('En proceso'), closeTo(230.3529, 0.001));
    });

    test('Pendiente maps to the legacy orange hue (#FF9900)', () {
      expect(alertMarkerHue('Pendiente'), closeTo(36.0, 0.001));
    });

    test('Cancelada maps to the legacy red hue (#FF0000)', () {
      expect(alertMarkerHue('Cancelada'), closeTo(0.0, 0.001));
    });

    test('matching is case-insensitive, like the entity\'s isX getters', () {
      expect(alertMarkerHue('RESUELTA'), closeTo(143.9423, 0.001));
      expect(alertMarkerHue('pendiente'), closeTo(36.0, 0.001));
    });

    test('an unknown state falls back to the legacy default (red, hue 0)', () {
      // The legacy Java switch has no default branch, so an unmatched state
      // leaves `float[3] color` at its zero-initialized value -> hue 0.0,
      // the same value the legacy app happens to use for "Cancelada".
      expect(alertMarkerHue('Desconocido'), 0.0);
      expect(alertMarkerHue(''), 0.0);
    });
  });
}
