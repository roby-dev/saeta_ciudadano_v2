import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../constants/app_constants.dart';
import 'socket_connection.dart';

/// [SocketConnection] backed by `package:socket_io_client`.
///
/// The underlying [socket_io.Socket] is created lazily on the first
/// [connect] call. Construction alone performs no I/O: auto-connect is
/// disabled, so building the socket doesn't open a connection.
///
/// The library's own automatic reconnection is disabled too
/// (`disableReconnection`): [RealtimeServiceImpl] owns the single bounded
/// retry policy instead, so a bad/expired token can't make the client hammer
/// the server in a loop.
class IoSocketConnection implements SocketConnection {
  IoSocketConnection({String? baseUrl})
      : _baseUrl = baseUrl ?? AppConstants.baseUrlSaeta;

  final String _baseUrl;
  socket_io.Socket? _socket;

  socket_io.Socket _ensureSocket() {
    return _socket ??= socket_io.io(
      _baseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );
  }

  @override
  set auth(Map<String, dynamic> value) => _ensureSocket().auth = value;

  @override
  void connect() => _ensureSocket().connect();

  @override
  void disconnect() => _socket?.disconnect();

  @override
  void dispose() => _socket?.dispose();

  @override
  void on(String event, void Function(dynamic data) handler) {
    _ensureSocket().on(event, (data) => handler(data));
  }

  @override
  void onConnect(void Function() handler) {
    _ensureSocket().onConnect((_) => handler());
  }

  @override
  void onConnectError(void Function(dynamic error) handler) {
    _ensureSocket().onConnectError((error) => handler(error));
  }

  @override
  void onDisconnect(void Function(dynamic reason) handler) {
    _ensureSocket().onDisconnect((reason) => handler(reason));
  }
}
