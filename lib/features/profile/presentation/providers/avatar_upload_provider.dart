import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/services/avatar_file_validator.dart';
import '../../domain/services/avatar_image_picker.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';

/// Manages the "pick a photo (camera or gallery) and upload it as my
/// avatar" flow against `PUT /v1/uploads/:id`.
///
/// This provider deliberately does **not** track the current user's
/// `image`/avatar itself — the caller (`ProfileView`, via
/// `MainNavigationProvider.currentUser`) already owns that. On success,
/// [onUpdated] is invoked with the fresh `UserEntity` so the caller can
/// refresh immediately (same wiring pattern as `ProfileEditProvider`); on
/// failure nothing is called, so the current avatar is kept exactly as-is.
class AvatarUploadProvider extends ChangeNotifier {
  AvatarUploadProvider({
    required UploadAvatarUseCase uploadAvatarUseCase,
    required AvatarImagePicker imagePicker,
    required AvatarFileValidator fileValidator,
    required String userId,
    void Function(UserEntity updatedUser)? onUpdated,
    Future<int> Function(String path)? fileSizeReader,
  })  : _uploadAvatarUseCase = uploadAvatarUseCase,
        _imagePicker = imagePicker,
        _fileValidator = fileValidator,
        _userId = userId,
        _onUpdated = onUpdated,
        _fileSizeReader = fileSizeReader ?? ((path) => File(path).length());

  final UploadAvatarUseCase _uploadAvatarUseCase;
  final AvatarImagePicker _imagePicker;
  final AvatarFileValidator _fileValidator;
  final String _userId;
  final void Function(UserEntity updatedUser)? _onUpdated;
  final Future<int> Function(String path) _fileSizeReader;

  bool _isUploading = false;
  String? _errorMessage;

  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;

  /// Opens the camera, validates the pick, and uploads it. Returns `true`
  /// on a successful upload, `false` on cancellation, a rejected pick, or an
  /// upload failure (in the latter two cases [errorMessage] carries the
  /// reason).
  Future<bool> pickAndUploadFromCamera() =>
      _pickAndUpload(_imagePicker.pickFromCamera);

  /// Same as [pickAndUploadFromCamera] but opens the gallery instead.
  Future<bool> pickAndUploadFromGallery() =>
      _pickAndUpload(_imagePicker.pickFromGallery);

  Future<bool> _pickAndUpload(Future<String?> Function() pick) async {
    final path = await pick();
    if (path == null) return false; // user cancelled: no-op, no state change

    final sizeBytes = await _fileSizeReader(path);
    final validationError =
        _fileValidator.validate(path: path, sizeBytes: sizeBytes);
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    final result =
        await _uploadAvatarUseCase(_userId, filePath: path);

    final success = result.fold(
      (failure) {
        _errorMessage = failure.message;
        return false;
      },
      (updatedUser) {
        _errorMessage = null;
        _onUpdated?.call(updatedUser);
        return true;
      },
    );

    _isUploading = false;
    notifyListeners();
    return success;
  }
}
