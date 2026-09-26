/// Wraps the platform image-picker plugin behind a domain interface so the
/// pick-then-upload flow (`AvatarUploadProvider`) can be unit-tested without
/// a platform channel. The real implementation
/// (`ImagePickerAvatarPicker`, in `data/services/`) uses the plugin's own
/// `maxWidth`/`maxHeight`/`imageQuality` knobs to keep picked images well
/// under the backend's 5MB limit — no extra image-compression dependency.
abstract interface class AvatarImagePicker {
  /// Opens the camera. Returns the picked image's file path, or `null` if
  /// the user cancelled.
  Future<String?> pickFromCamera();

  /// Opens the gallery. Returns the picked image's file path, or `null` if
  /// the user cancelled.
  Future<String?> pickFromGallery();
}
