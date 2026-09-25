import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/network/account_disabled_notifier.dart';
import 'package:saeta_ciudadano_v2/core/network/token_refresher.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service_impl.dart';
import 'package:saeta_ciudadano_v2/core/realtime/socket_connection.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

class MockSocketConnection extends Mock implements SocketConnection {}

class MockTokenRefresher extends Mock implements TokenRefresher {}

void _noopDynamicHandler(dynamic _) {}

void _noopVoidHandler() {}

/// Flushes the microtask queue so fire-and-forget async work triggered by a
/// captured event handler (e.g. the reconnect retry) has a chance to
/// complete before assertions run.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MockSecureStorage storage;
  late MockSocketConnection socket;
  late MockTokenRefresher tokenRefresher;
  late AccountDisabledNotifier accountDisabledNotifier;
  late RealtimeServiceImpl service;

  // `socket.connect()` is invoked from inside fire-and-forget async retry
  // callbacks, so a plain counter (rather than repeated `verify(...).called`
  // checkpoints, which mocktail only counts against calls not already
  // claimed by an earlier `verify`) is the reliable way to assert "how many
  // times has connect() been called so far" at several points in one test.
  late int connectCallCount;
  // Indirection so individual tests can override the injected jitter
  // without rebuilding the service (which would double-register handlers
  // on the shared `socket` mock).
  late int Function() jitterFn;

  setUpAll(() {
    registerFallbackValue(_noopDynamicHandler);
    registerFallbackValue(_noopVoidHandler);
    registerFallbackValue(const <String, dynamic>{});
  });

  setUp(() {
    storage = MockSecureStorage();
    socket = MockSocketConnection();
    tokenRefresher = MockTokenRefresher();
    accountDisabledNotifier = AccountDisabledNotifier();
    connectCallCount = 0;
    // Zero jitter by default so backoff assertions can use exact values; a
    // dedicated test overrides this to check jitter is actually added.
    jitterFn = () => 0;

    when(() => storage.clearSession()).thenAnswer((_) async {});
    when(() => socket.connect()).thenAnswer((_) {
      connectCallCount++;
    });

    service = RealtimeServiceImpl(
      socket: socket,
      storage: storage,
      accountDisabledNotifier: accountDisabledNotifier,
      tokenRefresher: tokenRefresher,
      jitterMillis: () => jitterFn(),
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

  void Function(dynamic) capturedOnConnectError() {
    final captured =
        verify(() => socket.onConnectError(captureAny())).captured;
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
      expect(connectCallCount, 1);
    });

    test('does not connect when there is no stored session', () async {
      when(() => storage.getToken()).thenAnswer((_) async => null);

      await service.connect();

      expect(connectCallCount, 0);
    });

    test('does not connect when the stored token is empty', () async {
      when(() => storage.getToken()).thenAnswer((_) async => '');

      await service.connect();

      expect(connectCallCount, 0);
    });
  });

  group('disconnect', () {
    test('disconnects the socket', () async {
      await service.disconnect();

      verify(() => socket.disconnect()).called(1);
    });

    test('cancels a pending backoff retry timer', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('transport close');
        async.flushMicrotasks();

        unawaited(service.disconnect());
        async.flushMicrotasks();

        // Advance well past the first backoff delay: no retry should fire.
        async.elapse(const Duration(seconds: 40));

        // Only the initial connect(); the pending retry was cancelled.
        expect(connectCallCount, 1);
      });
    });
  });

  group('network-type backoff retry', () {
    test('schedules the first retry 1s after a network disconnect', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('transport close');
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 999));
        async.flushMicrotasks();
        expect(connectCallCount, 1); // still not yet

        async.elapse(const Duration(milliseconds: 2));
        async.flushMicrotasks();
        expect(connectCallCount, 2); // fired at ~1s
      });
    });

    test('doubles the backoff on each consecutive failure, capped at 30s',
        () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onConnectError = capturedOnConnectError();
        unawaited(service.connect());
        async.flushMicrotasks();
        expect(connectCallCount, 1);

        final expectedDelaysSeconds = [1, 2, 4, 8, 16, 30, 30];

        for (final delaySeconds in expectedDelaysSeconds) {
          final before = connectCallCount;
          onConnectError('connect_error');
          async.flushMicrotasks();

          async.elapse(Duration(seconds: delaySeconds - 1));
          async.flushMicrotasks();
          expect(connectCallCount, before); // not yet

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(connectCallCount, before + 1); // fired right on schedule
        }
      });
    });

    test('resets the backoff to the first step after a successful connect',
        () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onConnectError = capturedOnConnectError();
        final onConnect = capturedOnConnect();
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        // First failure: next delay would be 2s if not reset later.
        onConnectError('connect_error');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        async.flushMicrotasks();
        expect(connectCallCount, 2); // initial + retry 1

        onConnect();
        async.flushMicrotasks();

        onDisconnect('ping timeout');
        async.flushMicrotasks();

        // If the backoff had not reset, 1s would not be enough (the next
        // step would be 2s). Reset means the very next retry is 1s again.
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        async.flushMicrotasks();

        expect(connectCallCount, 3); // + retry 2, at the reset 1s delay
      });
    });

    test('adds bounded jitter on top of the base delay', () {
      fakeAsync((async) {
        jitterFn = () => 137;
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('transport close');
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1136));
        async.flushMicrotasks();
        expect(connectCallCount, 1); // base(1000) + jitter(137) not yet elapsed

        async.elapse(const Duration(milliseconds: 2));
        async.flushMicrotasks();
        expect(connectCallCount, 2);
      });
    });

    test('re-reads the token from SecureStorage on every retry', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        when(() => storage.getToken()).thenAnswer((_) async => 'access-2');
        onDisconnect('transport close');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        async.flushMicrotasks();

        verify(() => socket.auth = {'token': 'access-2'}).called(1);
      });
    });

    test('keeps retrying indefinitely (no retry cap)', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        for (var i = 0; i < 10; i++) {
          onDisconnect('transport close');
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 31)); // covers any capped delay
          async.flushMicrotasks();
        }

        expect(connectCallCount, 11); // initial + 10 retries
      });
    });
  });

  group('auth-rejected disconnect (io server disconnect)', () {
    test(
        'attempts one token refresh then reconnects once, without scheduling '
        'a network backoff retry', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        when(() => tokenRefresher.refresh())
            .thenAnswer((_) async => 'access-2');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();
        expect(connectCallCount, 1);

        // Simulates TokenRefresher having already persisted the new token
        // to SecureStorage by the time the auth-rejection reconnect reads
        // it (as the real TokenRefresher does via `storage.updateTokens`).
        when(() => storage.getToken()).thenAnswer((_) async => 'access-2');
        onDisconnect('io server disconnect');
        async.flushMicrotasks();

        verify(() => tokenRefresher.refresh()).called(1);
        verify(() => socket.auth = {'token': 'access-2'}).called(1);
        expect(connectCallCount, 2);

        // No backoff timer was scheduled for this disconnect.
        async.elapse(const Duration(seconds: 40));
        expect(connectCallCount, 2);
      });
    });

    test('stops retrying after a second consecutive auth rejection', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        when(() => tokenRefresher.refresh())
            .thenAnswer((_) async => 'access-2');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('io server disconnect');
        async.flushMicrotasks();
        expect(connectCallCount, 2); // initial + 1 auth retry

        // Rejected again right after the single auth-retry reconnect.
        onDisconnect('io server disconnect');
        async.flushMicrotasks();

        // No second refresh attempt, no further reconnect, no backoff.
        verify(() => tokenRefresher.refresh()).called(1);
        expect(connectCallCount, 2);
        async.elapse(const Duration(seconds: 40));
        expect(connectCallCount, 2);
      });
    });

    test('a failed refresh stops retrying without a second attempt', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        when(() => tokenRefresher.refresh()).thenAnswer((_) async => null);
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('io server disconnect');
        async.flushMicrotasks();

        verify(() => tokenRefresher.refresh()).called(1);
        // Only the initial connect(); refresh failed so no reconnect.
        expect(connectCallCount, 1);
        async.elapse(const Duration(seconds: 40));
        expect(connectCallCount, 1);
      });
    });

    test('the auth-retry guard resets after a later successful connect', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        when(() => tokenRefresher.refresh())
            .thenAnswer((_) async => 'access-2');
        final onDisconnect = capturedOnDisconnect();
        final onConnect = capturedOnConnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('io server disconnect');
        async.flushMicrotasks();
        expect(connectCallCount, 2);

        onConnect();
        async.flushMicrotasks();

        onDisconnect('io server disconnect');
        async.flushMicrotasks();

        // A fresh disconnect after a real successful connect gets its own
        // single auth-retry attempt again.
        verify(() => tokenRefresher.refresh()).called(2);
        expect(connectCallCount, 3);
      });
    });
  });

  group('explicit disconnect never retries', () {
    test('a manual disconnect does not trigger a retry', () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();
      final onDisconnect = capturedOnDisconnect();

      await service.disconnect();
      onDisconnect('io client disconnect');
      await _flush();

      expect(connectCallCount, 1);
    });

    test('a disableUser disconnect does not trigger a reconnect retry',
        () async {
      when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
      await service.connect();
      final onDisconnect = capturedOnDisconnect();

      final messageFuture = accountDisabledNotifier.stream.first;
      capturedHandlerFor('disableUser')('Su cuenta ha sido deshabilitada');
      await messageFuture;

      onDisconnect('io server disconnect');
      await _flush();

      expect(connectCallCount, 1);
      verifyNever(() => tokenRefresher.refresh());
    });

    test('disableUser cancels a pending backoff retry timer', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('transport close');
        async.flushMicrotasks();

        capturedHandlerFor('disableUser')('Su cuenta ha sido deshabilitada');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 40));

        expect(connectCallCount, 1);
      });
    });
  });

  group('reconnectOnResume', () {
    test('reconnects immediately and resets backoff when the socket is down',
        () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onDisconnect = capturedOnDisconnect();
        unawaited(service.connect());
        async.flushMicrotasks();

        onDisconnect('transport close');
        async.flushMicrotasks();
        // A retry is now pending ~1s out; nothing has fired yet.
        expect(connectCallCount, 1);

        unawaited(service.reconnectOnResume());
        async.flushMicrotasks();

        // Reconnected immediately, without waiting for the backoff timer.
        expect(connectCallCount, 2);

        // The old pending timer must not fire a third connect() later.
        async.elapse(const Duration(seconds: 40));
        expect(connectCallCount, 2);
      });
    });

    test('is a no-op when already connected', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        final onConnect = capturedOnConnect();
        unawaited(service.connect());
        async.flushMicrotasks();
        onConnect();

        unawaited(service.reconnectOnResume());
        async.flushMicrotasks();

        expect(connectCallCount, 1);
      });
    });

    test('is a no-op after an explicit disconnect', () {
      fakeAsync((async) {
        when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
        unawaited(service.connect());
        async.flushMicrotasks();

        unawaited(service.disconnect());
        async.flushMicrotasks();

        unawaited(service.reconnectOnResume());
        async.flushMicrotasks();

        expect(connectCallCount, 1);
      });
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
  });
}
