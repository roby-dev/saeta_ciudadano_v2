import 'package:equatable/equatable.dart';

/// A contact phone number picked by the user from the device address book.
class PickedContact extends Equatable {
  const PickedContact({required this.name, required this.phoneNumber});

  final String name;

  /// The raw, device-formatted phone number as picked (not yet normalized).
  final String phoneNumber;

  @override
  List<Object?> get props => [name, phoneNumber];
}

/// Opens the native OS contact picker so the user selects a contact and one
/// of their phone numbers. No `READ_CONTACTS` permission is required: the
/// picker runs out-of-process and only the single selected contact is
/// handed back to the app (see `flutter_native_contact_picker`).
abstract interface class DeviceContactPicker {
  /// Returns `null` when the user cancels the picker.
  Future<PickedContact?> pickContactPhoneNumber();
}
