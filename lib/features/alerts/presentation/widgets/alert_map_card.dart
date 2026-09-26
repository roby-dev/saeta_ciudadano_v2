import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map/alert_map_coordinates.dart';
import '../map/alert_marker_hue.dart';
import '../map/alert_maps_url_builder.dart';
import '../map/map_style_asset.dart';

/// Legacy zoom level for the alert detail map (`Config.MAP_ZOM` in the
/// Android app).
const double _legacyMapZoom = 16;

const double _mapCardHeight = 180;

/// Fixed-height, rounded card showing the alert's position with one
/// state-colored marker, legacy zoom and map style. Shows a placeholder
/// instead of a map when the coordinates are missing/invalid (see
/// [alertMapCoordinates]).
///
/// The map is deliberately non-interactive: it sits inside a
/// `DraggableScrollableSheet`, so its own pan/zoom gestures are disabled to
/// avoid fighting the sheet's scroll (only the marker's info window and the
/// external "open in Google Maps" button remain interactive). On Android,
/// `liteModeEnabled` renders it as a static bitmap instead of a live GL
/// surface, which is both cheaper and avoids any surface-embedding quirks
/// inside a scrollable sheet; the plugin ignores this flag on iOS, so the
/// gesture flags above are what keeps iOS non-interactive there.
class AlertMapCard extends StatefulWidget {
  const AlertMapCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.stateName,
    required this.typeName,
  });

  final double latitude;
  final double longitude;
  final String stateName;
  final String typeName;

  @override
  State<AlertMapCard> createState() => _AlertMapCardState();
}

class _AlertMapCardState extends State<AlertMapCard> {
  late final Future<String> _styleFuture;

  @override
  void initState() {
    super.initState();
    _styleFuture = loadMapStyleJson();
  }

  Future<void> _openInGoogleMaps() async {
    final uri = buildExternalMapsUri(widget.latitude, widget.longitude);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort only: a launch failure here must never break the alert
      // detail view, same convention as EmergencyContactsProvider's SMS
      // launch.
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = alertMapCoordinates(widget.latitude, widget.longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: _mapCardHeight,
            child: position == null
                ? _buildPlaceholder()
                : _buildMap(position),
          ),
        ),
        if (position != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openInGoogleMaps,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Abrir en Google Maps'),
            ),
          ),
      ],
    );
  }

  Widget _buildMap(LatLng position) {
    return FutureBuilder<String>(
      future: _styleFuture,
      builder: (context, snapshot) {
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: _legacyMapZoom,
          ),
          style: snapshot.data,
          markers: {
            Marker(
              markerId: const MarkerId('alert-position'),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                alertMarkerHue(widget.stateName),
              ),
              infoWindow: InfoWindow(title: widget.typeName),
            ),
          },
          // Non-interactive by default: only the marker's info window and
          // the external "open in Google Maps" button remain usable.
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: true,
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_outlined, color: Colors.grey.shade600, size: 32),
          const SizedBox(height: 8),
          Text(
            'Ubicación no disponible',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
