import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/network/auth_interceptor.dart';
import 'package:saeta_ciudadano_v2/core/network/session_expired_notifier.dart';
import 'package:saeta_ciudadano_v2/core/network/token_refresher.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';

import 'fake_http_client_adapter.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage storage;
  late SessionExpiredNotifier notifier;
  late Dio dio;
  late Dio authDio;
  late FakeHttpClientAdapter dioAdapter;
  late FakeHttpClientAdapter authAdapter;

  setUp(() {
    storage = MockSecureStorage();
    notifier = SessionExpiredNotifier();

    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    authDio = Dio(BaseOptions(baseUrl: 'https://api.test'));

    dio.interceptors.add(
      AuthInterceptor(
        dioProvider: () => dio,
        storage: storage,
        sessionExpiredNotifier: notifier,
        tokenRefresher: TokenRefresher(
          authDio: authDio,
          storage: storage,
          sessionExpiredNotifier: notifier,
        ),
      ),
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  test('attaches Authorization header from storage when a token exists',
      () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {'ok': true}),
    );
    dio.httpClientAdapter = dioAdapter;

    await dio.get<dynamic>('/v1/alerts/user/u1');

    expect(
      dioAdapter.requests.single.headers['Authorization'],
      'Bearer access-1',
    );
  });

  test('does not attach a header on public endpoints', () async {
    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {'ok': true}),
    );
    dio.httpClientAdapter = dioAdapter;

    await dio.post<dynamic>('/v1/auth/login', data: {});

    expect(
      dioAdapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    verifyNever(() => storage.getToken());
  });

  test('does not attach a header when registering (POST /v1/users)',
      () async {
    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(201, {'ok': true}),
    );
    dio.httpClientAdapter = dioAdapter;

    await dio.post<dynamic>('/v1/users', data: {});

    expect(
      dioAdapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    verifyNever(() => storage.getToken());
  });

  test('does not attach a header on DNI lookup (GET /v1/users/dni/:dni)',
      () async {
    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {'ok': true}),
    );
    dio.httpClientAdapter = dioAdapter;

    await dio.get<dynamic>('/v1/users/dni/12345678');

    expect(
      dioAdapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    verifyNever(() => storage.getToken());
  });

  test('attaches a header on GET /v1/users/:id (own profile lookup)',
      () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {'ok': true}),
    );
    dio.httpClientAdapter = dioAdapter;

    await dio.get<dynamic>('/v1/users/u1');

    expect(
      dioAdapter.requests.single.headers['Authorization'],
      'Bearer access-1',
    );
  });

  test('attaches a header on PATCH /v1/users/:id (emergency contacts save)',
      () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'access-1');
    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {'ok': true}),
    );
    dio.httpClientAdapter = dioAdapter;

    await dio.patch<dynamic>('/v1/users/u1', data: {});

    expect(
      dioAdapter.requests.single.headers['Authorization'],
      'Bearer access-1',
    );
  });

  test('a 401 triggers a refresh and retries the original request once',
      () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'expired-token');
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).thenAnswer((_) async {});

    var alertCalls = 0;
    dioAdapter = FakeHttpClientAdapter((options) async {
      alertCalls++;
      if (alertCalls == 1) {
        return const FakeResponse(401, {'message': 'expired'});
      }
      return const FakeResponse(200, {'alerts': <dynamic>[]});
    });
    dio.httpClientAdapter = dioAdapter;

    authAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
        'user': <String, dynamic>{},
      }),
    );
    authDio.httpClientAdapter = authAdapter;

    final response = await dio.get<dynamic>('/v1/alerts/user/u1');

    expect(response.statusCode, 200);
    expect(authAdapter.requests, hasLength(1));
    expect(authAdapter.requests.single.data, {'refreshToken': 'refresh-1'});
    expect(dioAdapter.requests, hasLength(2));
    expect(
      dioAdapter.requests.last.headers['Authorization'],
      'Bearer new-access',
    );
    verify(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).called(1);
  });

  test('concurrent 401s share exactly one refresh call', () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'expired-token');
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).thenAnswer((_) async {});

    final callCounts = <String, int>{};
    dioAdapter = FakeHttpClientAdapter((options) async {
      final count = (callCounts[options.path] ?? 0) + 1;
      callCounts[options.path] = count;
      // Small delay so both requests reach the 401 branch before either
      // finishes its refresh-and-retry cycle.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (count == 1) {
        return const FakeResponse(401, {'message': 'expired'});
      }
      return const FakeResponse(200, {'ok': true});
    });
    dio.httpClientAdapter = dioAdapter;

    authAdapter = FakeHttpClientAdapter((options) async {
      await Future<void>.delayed(const Duration(milliseconds: 15));
      return const FakeResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
        'user': <String, dynamic>{},
      });
    });
    authDio.httpClientAdapter = authAdapter;

    final results = await Future.wait([
      dio.get<dynamic>('/v1/alerts/user/u1'),
      dio.get<dynamic>('/v1/types'),
    ]);

    expect(results[0].statusCode, 200);
    expect(results[1].statusCode, 200);
    expect(authAdapter.requests, hasLength(1));
  });

  test(
      'clears the session and notifies when there is no refresh token, '
      'rejecting with the original error', () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'expired-token');
    when(() => storage.getRefreshToken()).thenAnswer((_) async => null);
    when(() => storage.clearSession()).thenAnswer((_) async {});

    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(401, {'message': 'expired'}),
    );
    dio.httpClientAdapter = dioAdapter;

    final expiredFuture = notifier.stream.first;

    await expectLater(
      dio.get<dynamic>('/v1/alerts/user/u1'),
      throwsA(isA<DioException>()),
    );

    await expiredFuture.timeout(const Duration(seconds: 1));
    verify(() => storage.clearSession()).called(1);
    verifyNever(() => storage.updateTokens(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
        ));
  });

  test(
      'clears the session and notifies when the refresh call itself fails',
      () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'expired-token');
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.clearSession()).thenAnswer((_) async {});

    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(401, {'message': 'expired'}),
    );
    dio.httpClientAdapter = dioAdapter;

    authAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(400, {'message': 'invalid'}),
    );
    authDio.httpClientAdapter = authAdapter;

    final expiredFuture = notifier.stream.first;

    await expectLater(
      dio.get<dynamic>('/v1/alerts/user/u1'),
      throwsA(isA<DioException>()),
    );

    await expiredFuture.timeout(const Duration(seconds: 1));
    expect(authAdapter.requests, hasLength(1));
    verify(() => storage.clearSession()).called(1);
  });

  test(
      'clears the session without looping when the retried request is '
      '401 again', () async {
    when(() => storage.getToken()).thenAnswer((_) async => 'expired-token');
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'refresh-1');
    when(() => storage.updateTokens(
          token: 'new-access',
          refreshToken: 'new-refresh',
        )).thenAnswer((_) async {});
    when(() => storage.clearSession()).thenAnswer((_) async {});

    dioAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(401, {'message': 'expired'}),
    );
    dio.httpClientAdapter = dioAdapter;

    authAdapter = FakeHttpClientAdapter(
      (options) async => const FakeResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
        'user': <String, dynamic>{},
      }),
    );
    authDio.httpClientAdapter = authAdapter;

    final expiredFuture = notifier.stream.first;

    await expectLater(
      dio.get<dynamic>('/v1/alerts/user/u1'),
      throwsA(isA<DioException>()),
    );

    await expiredFuture.timeout(const Duration(seconds: 1));
    // Exactly one refresh call and one retry — no infinite loop.
    expect(authAdapter.requests, hasLength(1));
    expect(dioAdapter.requests, hasLength(2));
    verify(() => storage.clearSession()).called(1);
  });
}
