import '../../../../core/constants/app_constants.dart';

/// Builds the `GET /v1/uploads/:photo` URL used to render a user's avatar
/// from their `image` file id. That endpoint is public (no `Authorization`
/// header needed — confirmed by reading `saeta-backend-v2`'s
/// `UploadsController.returnImage`, which carries no `@UseGuards`), and it's
/// rendered via `Image.network` rather than the app's `Dio` instance, so
/// `AuthInterceptor`'s public-path list is irrelevant here: `Image.network`
/// never goes through `Dio` at all.
///
/// A new upload gets a brand-new random file id server-side (confirmed by
/// reading `LocalStorageService.upload`, which names the file
/// `randomUUID().<ext>`), so the URL itself always changes after a
/// successful replace — no manual cache-busting query parameter is needed.
class AvatarUrlBuilder {
  const AvatarUrlBuilder({this.baseUrl = AppConstants.baseUrlSaeta});

  final String baseUrl;

  /// Returns `null` when [image] is empty (no avatar uploaded yet), so the
  /// caller can show a placeholder instead of requesting a broken URL.
  String? build(String image) {
    if (image.isEmpty) return null;
    return '$baseUrl/v1/uploads/$image';
  }
}
