import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import '../../domain/services/device_contact_picker.dart';

/// [DeviceContactPicker] backed by `package:flutter_native_contact_picker`,
/// which requires no `READ_CONTACTS` permission.
class NativeDeviceContactPicker implements DeviceContactPicker {
  NativeDeviceContactPicker([FlutterNativeContactPicker? picker])
      : _picker = picker ?? FlutterNativeContactPicker();

  final FlutterNativeContactPicker _picker;

  @override
  Future<PickedContact?> pickContactPhoneNumber() async {
    final contact = await _picker.selectPhoneNumber();
    if (contact == null) return null;

    final phoneNumber = contact.selectedPhoneNumber ??
        (contact.phoneNumbers?.isNotEmpty == true
            ? contact.phoneNumbers!.first
            : null);
    if (phoneNumber == null || phoneNumber.isEmpty) return null;

    return PickedContact(
      name: contact.fullName ?? '',
      phoneNumber: phoneNumber,
    );
  }
}
