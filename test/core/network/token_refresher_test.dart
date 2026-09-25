import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/network/session_expired_notifier.dart';
import 'package:saeta_ciudadano_v2/core/network/token_refresher.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';

import 'fake_http_client_adapter.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

/// Single-flight token refresh shared by [AuthInterceptor] (401 retries)
/// and `RealtimeServiceImpl` (auth-rejected socket reconnects) — see
/// `token_refresher.dart`. Exercised directly here; `auth_interceptor_test`
/// exercises the same logic end-to-end through a real `Dio` 401 flow.
void main() {
  late MockSecureStorage storage;
  late SessionExpiredNotifier notifier;
  late Dio authDio;
  late FakeHttpClientAdapter authAdapter;
  late TokenRefresher refresher;

  setUp(() {
    storage = MockSecureStorage();
    notifier = SessionExpiredNotifier();
    authDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    refresher = TokenRefresher(
      authDio: authDio,
      storage: storage,
      sessionExpiredNotifier: notifier,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  test('returns the new access token and persists both tokens on success',
      () async {
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).thenAnswer((_) async {});

    authAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      }),
    );
    authDio.httpClientAdapter = authAdapter;

    final token = await refresher.refresh();

    expect(token, 'new-access');
    expect(authAdapter.requests.single.data, {'refreshToken': 'refresh-1'});
    verify(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).called(1);
  });

  test('returns null and clears the session when there is no refresh token',
      () async {
    when(() => storage.getRefreshToken()).thenAnswer((_) async => null);
    when(() => storage.clearSession()).thenAnswer((_) async {});

    final expiredFuture = notifier.stream.first;

    final token = await refresher.refresh();

    expect(token, isNull);
    await expiredFuture.timeout(const Duration(seconds: 1));
    verify(() => storage.clearSession()).called(1);
  });

  test('returns null and clears the session when the refresh call fails',
      () async {
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.clearSession()).thenAnswer((_) async {});

    authAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(400, {'message': 'invalid'}),
    );
    authDio.httpClientAdapter = authAdapter;

    final expiredFuture = notifier.stream.first;

    final token = await refresher.refresh();

    expect(token, isNull);
    await expiredFuture.timeout(const Duration(seconds: 1));
    verify(() => storage.clearSession()).called(1);
  });

  test('concurrent calls share exactly one refresh call', () async {
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).thenAnswer((_) async {});

    authAdapter = FakeHttpClientAdapter((options) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return const FakeResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      });
    });
    authDio.httpClientAdapter = authAdapter;

    final results = await Future.wait<String?>(
      [refresher.refresh(), refresher.refresh()],
    );

    expect(results, ['new-access', 'new-access']);
    expect(authAdapter.requests, hasLength(1));
  });
}
