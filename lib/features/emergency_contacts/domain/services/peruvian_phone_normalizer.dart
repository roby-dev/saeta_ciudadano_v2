/// Normalizes device-formatted Peruvian phone numbers (e.g.
/// `"+51 987 654 321"`, `"987-654-321"`) into the plain 9-digit format the
/// backend expects, mirroring the normalization the backend itself applies
/// (see `EmergencyContactDto` in saeta-backend-v2).
class PeruvianPhoneNormalizer {
  const PeruvianPhoneNormalizer();

  static const String _countryCode = '51';
  static final RegExp _nonDigits = RegExp(r'\D');
  static final RegExp _ninePeruDigits = RegExp(r'^\d{9}$');

  /// Returns the normalized 9-digit phone number, or `null` when [rawPhone]
  /// cannot be normalized to a valid Peruvian mobile number.
  String? normalize(String rawPhone) {
    final digits = rawPhone.replaceAll(_nonDigits, '');
    final normalized =
        (digits.length == 11 && digits.startsWith(_countryCode))
            ? digits.substring(_countryCode.length)
            : digits;
    return _ninePeruDigits.hasMatch(normalized) ? normalized : null;
  }
}
