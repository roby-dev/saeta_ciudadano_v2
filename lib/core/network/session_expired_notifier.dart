import 'dart:async';

/// Broadcasts a signal whenever the current session is invalidated because
/// the access token could not be refreshed (missing/invalid refresh token,
/// or the refresh endpoint itself rejects the request).
///
/// The app layer listens to [stream] and navigates back to the login screen
/// when a session-expired event is received.
class SessionExpiredNotifier {
  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  /// Notifies listeners that the current session has expired.
  void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
  }
}
