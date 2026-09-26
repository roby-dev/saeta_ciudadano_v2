/// Legacy-parity marker hue per alert state.
///
/// Mirrors the Android app's `AlertDetailFragment.markPoiOnMap`, which reads
/// `Config.ALERT_STATE_*` (a raw Spanish state name) and converts one of four
/// hardcoded hex colors from `strings.xml` (`textColorState*`) to an HSV hue
/// via `Color.colorToHSV`, then builds the marker with
/// `BitmapDescriptorFactory.defaultMarker(hue)`. The hues below are that same
/// hex-to-HSV conversion, computed once and hardcoded here (no color/HSV math
/// dependency needed just for four constants):
///   - Resuelta   (`#17E76A`, green)  -> 143.9423076923077
///   - En proceso (`#0029FF`, blue)   -> 230.3529411764706
///   - Pendiente  (`#FF9900`, orange) -> 36.0
///   - Cancelada  (`#FF0000`, red)    -> 0.0
///
/// Matching is a case-insensitive substring check, the same convention
/// `CitizenAlertEntity.isResolved`/`isInProcess`/`isPending`/`isCancelled`
/// already use for `stateName`.
double alertMarkerHue(String stateName) {
  final normalized = stateName.toLowerCase();
  if (normalized.contains('resuelta')) return _resolvedHue;
  if (normalized.contains('proceso')) return _inProcessHue;
  if (normalized.contains('pendiente')) return _pendingHue;
  if (normalized.contains('cancel')) return _cancelledHue;
  // The legacy Java `switch (state)` has no default branch, so an
  // unrecognized state leaves `float[3] color` at Java's zero-initialized
  // value, i.e. hue 0.0 - the same value the legacy app happens to use for
  // "Cancelada". Reused here as the documented default for an unknown state.
  return _defaultHue;
}

const double _resolvedHue = 143.9423076923077;
const double _inProcessHue = 230.3529411764706;
const double _pendingHue = 36.0;
const double _cancelledHue = 0.0;
const double _defaultHue = _cancelledHue;
