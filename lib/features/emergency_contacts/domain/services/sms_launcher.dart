/// Opens the device's SMS composer with the given recipients and message
/// body prefilled, so the user reviews and taps send themselves (no
/// SEND_SMS permission, no silent SMS).
abstract interface class SmsLauncher {
  Future<void> launch({
    required List<String> phoneNumbers,
    required String body,
  });
}

/// Thrown when the platform reports it could not open an SMS composer for
/// the built URI (e.g. no SMS app available).
class SmsLaunchException implements Exception {
  const SmsLaunchException(this.message);

  final String message;

  @override
  String toString() => 'SmsLaunchException: $message';
}
