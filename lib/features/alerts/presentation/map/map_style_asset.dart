import 'package:flutter/services.dart' show rootBundle;

/// Legacy-parity Google Maps JSON style, ported verbatim from the Android
/// app's `res/raw/map_style.json` (loaded there via
/// `MapStyleOptions.loadRawResourceStyle`), bundled here as a plain asset
/// declared in `pubspec.yaml`.
const String mapStyleAssetPath = 'assets/map_style.json';

/// Loads the raw JSON string for [GoogleMap.style].
Future<String> loadMapStyleJson() => rootBundle.loadString(mapStyleAssetPath);
