/// Builds the `tel:` URI used to launch the device dialer with [phone]
/// prefilled.
class TelUriBuilder {
  const TelUriBuilder();

  Uri build(String phone) => Uri(scheme: 'tel', path: phone);
}
