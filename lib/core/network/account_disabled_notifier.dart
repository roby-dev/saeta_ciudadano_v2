import 'dart:async';

/// Broadcasts a signal whenever the realtime backend disables the current
/// user's account (the `disableUser` Socket.IO event) and force-disconnects
/// the socket.
///
/// The app layer listens to [stream] to show the server-provided message and
/// navigate back to the login screen, mirroring [SessionExpiredNotifier]'s
/// role for token-refresh failures.
class AccountDisabledNotifier {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  Stream<String> get stream => _controller.stream;

  /// Notifies listeners that the current account was disabled, carrying the
  /// server-provided message.
  void notify(String message) {
    if (!_controller.isClosed) {
      _controller.add(message);
    }
  }

  void dispose() {
    _controller.close();
  }
}
