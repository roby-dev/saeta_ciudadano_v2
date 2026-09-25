/// Builds the `sms:` URI used to open the device SMS composer with
/// recipients and a message body prefilled.
///
/// Format: `sms:<phone1>,<phone2>,...?body=<url-encoded message>`. This is
/// understood by both Android and iOS. iOS note: multi-recipient prefill
/// support in the Messages composer has historically been inconsistent
/// across iOS versions (see evidence notes in the feature doc).
class SmsUriBuilder {
  const SmsUriBuilder();

  Uri build({
    required List<String> phoneNumbers,
    required String body,
  }) {
    return Uri(
      scheme: 'sms',
      path: phoneNumbers.join(','),
      queryParameters: {'body': body},
    );
  }
}
