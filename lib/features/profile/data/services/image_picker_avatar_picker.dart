import 'package:image_picker/image_picker.dart';
import '../../domain/services/avatar_image_picker.dart';

/// [AvatarImagePicker] backed by `package:image_picker`. Uses the plugin's
/// own `maxWidth`/`maxHeight`/`imageQuality` knobs to keep picked images
/// well under the backend's 5MB limit — no extra image-compression
/// dependency needed. Thin platform wrapper, deliberately untested (same
/// convention as `NativeDeviceContactPicker`/`UrlLauncherSmsLauncher`).
class ImagePickerAvatarPicker implements AvatarImagePicker {
  ImagePickerAvatarPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // 1600px / quality 85 comfortably keeps typical phone photos in the
  // hundreds-of-KB to low-single-digit-MB range, well under the 5MB limit;
  // AvatarFileValidator still rejects the rare outlier defensively.
  static const double _maxDimension = 1600;
  static const int _imageQuality = 85;

  @override
  Future<String?> pickFromCamera() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _imageQuality,
    );
    return file?.path;
  }
}
