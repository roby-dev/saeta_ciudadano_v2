/// Builds the emergency SMS body sent to emergency contacts when an alert
/// is sent, matching the legacy Android app's wording. Unlike the legacy
/// app (which greeted each contact by name in a separate SMS per contact),
/// this app opens a single multi-recipient composer, so the greeting is
/// generic rather than per-contact.
class SmsMessageBuilder {
  const SmsMessageBuilder();

  String buildBody({
    required String alertTypeName,
    required double latitude,
    required double longitude,
  }) {
    return 'Hola, tengo o acabo de presenciar un incidente del tipo '
        '$alertTypeName, por favor mantente alerta. '
        'Mi ubicación: https://maps.google.com/?q=$latitude,$longitude';
  }
}
