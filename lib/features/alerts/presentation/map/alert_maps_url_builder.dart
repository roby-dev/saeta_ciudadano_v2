/// Builds the URI for "open this position in the external Google Maps app",
/// a plain HTTPS Maps search URL that any device resolves to the Google Maps
/// app when it's installed (no `geo:`/app-specific scheme needed).
Uri buildExternalMapsUri(double latitude, double longitude) {
  return Uri.https(
    'www.google.com',
    '/maps/search/',
    {
      'api': '1',
      'query': '$latitude,$longitude',
    },
  );
}
