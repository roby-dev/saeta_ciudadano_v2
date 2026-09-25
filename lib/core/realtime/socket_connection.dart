/// Thin seam around the Socket.IO client library so [RealtimeServiceImpl]
/// (in `realtime_service_impl.dart`) stays unit-testable without opening a
/// real network connection.
///
/// The concrete adapter ([IoSocketConnection]) wraps `package:socket_io_client`
/// and is intentionally left without a dedicated unit test, consistent with
/// this codebase's convention for thin platform/vendor wrappers (e.g.
/// `NativeDeviceContactPicker`, `UrlLauncherSmsLauncher`).
abstract class SocketConnection {
  /// The handshake auth payload (`{'token': <access token>}`), read by the
  /// socket on the next [connect] call.
  set auth(Map<String, dynamic> value);

  /// Opens the connection (or reconnects) using the current [auth] payload.
  void connect();

  /// Closes the connection. A deliberate call here must not be followed by
  /// an automatic reconnect.
  void disconnect();

  /// Releases the underlying socket and clears its listeners.
  void dispose();

  /// Subscribes to a server-emitted event.
  void on(String event, void Function(dynamic data) handler);

  /// Fires once the connection is established (including reconnects).
  void onConnect(void Function() handler);

  /// Fires when a connection attempt fails (e.g. an auth error).
  void onConnectError(void Function(dynamic error) handler);

  /// Fires whenever the connection is lost, for any reason (deliberate
  /// disconnect, network error, or a server-initiated disconnect).
  void onDisconnect(void Function(dynamic reason) handler);
}
