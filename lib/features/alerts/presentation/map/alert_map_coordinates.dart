import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Converts (latitude, longitude) into a validated [LatLng], or `null` when
/// the pair can't represent a real reported position:
///   - NaN on either axis;
///   - out of the valid lat ([-90, 90]) / lng ([-180, 180]) range;
///   - the exact (0, 0) pair, which `CitizenAlertModel.fromJson` uses as its
///     "missing" default when the backend doesn't send a coordinate (see
///     `lib/features/alerts/data/models/citizen_alert_model.dart`), so it can
///     never be a genuine alert position in this app.
///
/// A single axis legitimately sitting at 0 (equator or prime meridian) is
/// still valid - only the exact (0, 0) pair is treated as the sentinel.
LatLng? alertMapCoordinates(double latitude, double longitude) {
  if (latitude.isNaN || longitude.isNaN) return null;
  if (latitude == 0 && longitude == 0) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;
  return LatLng(latitude, longitude);
}
