import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'sms_launcher.dart';
import 'sms_uri_builder.dart';

/// [SmsLauncher] backed by `package:url_launcher`. The actual platform call
/// is injected as [launch] (defaulting to `url_launcher.launchUrl`) so this
/// class stays unit-testable without a platform channel.
class UrlLauncherSmsLauncher implements SmsLauncher {
  UrlLauncherSmsLauncher({
    SmsUriBuilder uriBuilder = const SmsUriBuilder(),
    Future<bool> Function(Uri uri)? launch,
  })  : _uriBuilder = uriBuilder,
        _launch = launch ?? url_launcher.launchUrl;

  final SmsUriBuilder _uriBuilder;
  final Future<bool> Function(Uri uri) _launch;

  @override
  Future<void> launch({
    required List<String> phoneNumbers,
    required String body,
  }) async {
    final uri = _uriBuilder.build(phoneNumbers: phoneNumbers, body: body);
    final launched = await _launch(uri);
    if (!launched) {
      throw SmsLaunchException('Could not open the SMS composer for $uri');
    }
  }
}
