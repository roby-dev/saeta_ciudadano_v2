import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../service_locator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/services/avatar_file_validator.dart';
import '../../domain/services/avatar_image_picker.dart';
import '../../domain/services/avatar_url_builder.dart';
import '../../domain/usecases/upload_avatar_usecase.dart';
import '../providers/avatar_upload_provider.dart';

enum _AvatarSource { camera, gallery }

/// Profile avatar: shows the current photo (from `GET /v1/uploads/:photo`,
/// via [AvatarUrlBuilder]) with a camera badge; tapping either opens a
/// bottom sheet to pick a new one from the camera or gallery.
///
/// Disabled (plain placeholder, no tap target) while [user] hasn't loaded
/// yet — mirrors `ProfileView`'s existing "Editar perfil" button, which is
/// disabled under the same condition.
class AvatarSection extends StatelessWidget {
  const AvatarSection({super.key, required this.user, required this.onUpdated});

  final UserEntity? user;
  final void Function(UserEntity updatedUser) onUpdated;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    if (user == null) {
      return const _AvatarPlaceholder(initial: 'U');
    }
    return ChangeNotifierProvider<AvatarUploadProvider>(
      key: ValueKey('avatar-upload-${user.id}'),
      create: (_) => AvatarUploadProvider(
        uploadAvatarUseCase: sl<UploadAvatarUseCase>(),
        imagePicker: sl<AvatarImagePicker>(),
        fileValidator: sl<AvatarFileValidator>(),
        userId: user.id,
        onUpdated: onUpdated,
      ),
      child: _AvatarWithBadge(user: user),
    );
  }
}

class _AvatarWithBadge extends StatelessWidget {
  const _AvatarWithBadge({required this.user});

  final UserEntity user;

  static const AvatarUrlBuilder _urlBuilder = AvatarUrlBuilder();

  Future<void> _openPicker(BuildContext context) async {
    final provider = context.read<AvatarUploadProvider>();
    final source = await showModalBottomSheet<_AvatarSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(sheetContext).pop(_AvatarSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AvatarSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final success = source == _AvatarSource.camera
        ? await provider.pickAndUploadFromCamera()
        : await provider.pickAndUploadFromGallery();

    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUploading = context.watch<AvatarUploadProvider>().isUploading;
    final imageUrl = _urlBuilder.build(user.image);
    final initial =
        user.fullName.trim().isNotEmpty ? user.fullName.trim()[0].toUpperCase() : 'U';

    return GestureDetector(
      onTap: isUploading ? null : () => _openPicker(context),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: SizedBox(
                width: 96,
                height: 96,
                child: imageUrl == null
                    ? _AvatarPlaceholder(initial: initial)
                    : Image.network(
                        imageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _AvatarPlaceholder(initial: initial),
                      ),
              ),
            ),
            if (isUploading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: -2,
              right: -2,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 48,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initial,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
