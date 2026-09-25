import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/network/account_disabled_notifier.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service_impl.dart';
import 'package:saeta_ciudadano_v2/core/realtime/socket_connection.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

class MockSocketConnection extends Mock implements SocketConnection {}

void _noopDynamicHandler(dynamic _) {}

void _noopVoidHandler() {}

/// Flushes the microtask queue so fire-and-forget async work triggered by a
/// captured event handler (e.g. the reconnect retry) has a chance to
/// complete before assertions run.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MockSecureStorage storage;
  late MockSocketConnection socket;
  late AccountDisabledNotifier accountDisabledNotifier;
  late RealtimeServiceImpl service;

  setUpAll(() {
    registerFallbackValue(_noopDynamicHandler);
    registerFallbackValue(_noopVoidHandler);
    registerFallbackValue(const <String, dynamic>{});
  });

  setUp(() {
    storage = MockSecureStorage();
    socket = MockSocketConnection();
    accountDisabledNotifier = AccountDisabledNotifier();

    when(() => storage.clearSession()).thenAnswer((_) async {});

    service = RealtimeServiceImpl(
      socket: socket,
      storage: storage,
      accountDisabledNotifier: accountDisabledNotifier,
    );
  });

  tearDown(() {
    accountDisabledNotifier.dispose();
  });

  void Function(dynamic) capturedHandlerFor(String event) {
    final captured = verify(() => socket.on(event, captureAny())).captured;
    return captured.single as void Function(dynamic);
  }

  void Function(dynamic) capturedOnDisconnect() {
    final captured = verify(() => socket.onDisconnect(captureAny())).captured;
    return captured.single as void Function(dynamic);
  }

  void Function() capturedOnConnect() {
    final captured = verify(() => socket.onConnect(captureAny())).captured;
    return captured.single as void Function();
  }

  group('connect', () {
    test('connects with the current token in the handshake auth', () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');

      await service.connect();

      verify(() => socket.auth = {'token': 'access-1'}).called(1);
      verify(() => socket.connect()).called(1);
    });

    test('does not connect when there is no stored session', () async {
      when(() => storage.getToken()).thenAnswer((_) async => null);

      await service.connect();

      verifyNever(() => socket.connect());
    });

    test('does not connect when the stored token is empty', () async {
      when(() => storage.getToken()).thenAnswer((_) async => '');

      await service.connect();

      verifyNever(() => socket.connect());
    });
  });

  group('disconnect', () {
    test('disconnects the socket', () async {
      await service.disconnect();

      verify(() => socket.disconnect()).called(1);
    });
  });

  group('reconnection', () {
    test('retries once with the refreshed token after a disconnect',
        () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();
      verify(() => socket.connect()).called(1);

      when(() => storage.getToken()).thenAnswer((_) async => 'access-2');
      capturedOnDisconnect()(null);
      await _flush();

      verify(() => socket.auth = {'token': 'access-2'}).called(1);
      verify(() => socket.connect()).called(1);
    });

    test('does not retry a second time before a successful reconnect',
        () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();

      final onDisconnect = capturedOnDisconnect();
      onDisconnect(null);
      await _flush();
      onDisconnect(null);
      await _flush();

      // One connect() from the initial call + exactly one retry.
      verify(() => socket.connect()).called(2);
    });

    test('retries again after a disconnect that follows a successful connect',
        () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();

      final onDisconnect = capturedOnDisconnect();
      final onConnect = capturedOnConnect();

      onDisconnect(null);
      await _flush();
      onConnect();
      onDisconnect(null);
      await _flush();

      // initial connect + first retry + second retry
      verify(() => socket.connect()).called(3);
    });

    test('a manual disconnect does not trigger a retry', () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();

      await service.disconnect();
      final onDisconnect = capturedOnDisconnect();
      onDisconnect(null);
      await _flush();

      // Only the initial connect(); no retry after a deliberate disconnect.
      verify(() => socket.connect()).called(1);
    });
  });

  group('updatedAlert', () {
    test('forwards the raw payload on the updatedAlerts stream', () async {
      final events = <Map<String, dynamic>>[];
      final subscription = service.updatedAlerts.listen(events.add);

      final handler = capturedHandlerFor('updatedAlert');
      handler({'id': 'a1', 'userId': 'u1', 'typeId': 't1', 'stateId': 's1'});
      await _flush();

      expect(events, [
        {'id': 'a1', 'userId': 'u1', 'typeId': 't1', 'stateId': 's1'},
      ]);
      await subscription.cancel();
    });
  });

  group('disableUser', () {
    test('clears the session, disconnects, and signals the message',
        () async {
      final messageFuture = accountDisabledNotifier.stream.first;

      final handler = capturedHandlerFor('disableUser');
      handler('Su cuenta ha sido deshabilitada');

      final message = await messageFuture;

      expect(message, 'Su cuenta ha sido deshabilitada');
      verify(() => storage.clearSession()).called(1);
      verify(() => socket.disconnect()).called(1);
    });

    test('a disableUser disconnect does not trigger a reconnect retry',
        () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();

      final messageFuture = accountDisabledNotifier.stream.first;
      capturedHandlerFor('disableUser')('Su cuenta ha sido deshabilitada');
      await messageFuture;

      final onDisconnect = capturedOnDisconnect();
      onDisconnect(null);
      await _flush();

      // Only the initial connect(); disableUser's own disconnect (and the
      // subsequent onDisconnect callback) must not retry.
      verify(() => socket.connect()).called(1);
    });
  });
}
