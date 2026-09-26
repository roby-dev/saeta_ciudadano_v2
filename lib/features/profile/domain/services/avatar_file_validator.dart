/// Client-side guard mirroring the backend's own avatar upload limits
/// (`UploadAvatarHandler.ALLOWED_EXTENSIONS` / the `FileInterceptor`'s 5MB
/// `fileSize` limit in `saeta-backend-v2`), so an obviously-invalid pick
/// fails fast with a Spanish message instead of round-tripping to the
/// server first. This runs *after* the picker's own maxWidth/maxHeight/
/// imageQuality already keep normal photos well under the limit — it's a
/// defensive check, not the primary size-control mechanism.
class AvatarFileValidator {
  const AvatarFileValidator();

  static const int maxSizeBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
  };

  /// Returns a Spanish error message when [path]/[sizeBytes] should be
  /// rejected before ever calling `UploadAvatarUseCase`, or `null` when the
  /// file is acceptable.
  String? validate({required String path, required int sizeBytes}) {
    final extension = _extensionOf(path);
    if (!allowedExtensions.contains(extension)) {
      return 'Formato de imagen no permitido. Usa PNG, JPG, JPEG, GIF o WEBP.';
    }
    if (sizeBytes > maxSizeBytes) {
      return 'La imagen supera el límite de 5 MB.';
    }
    return null;
  }

  String _extensionOf(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex + 1).toLowerCase();
  }
}
