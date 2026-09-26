import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/usecases/login_usecase.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/bloc/auth_event.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/bloc/auth_state.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}

class MockSecureStorage extends Mock implements SecureStorage {}

const _user = UserEntity(
  id: 'u1',
  name: 'Ana',
  lastname: 'Lopez',
  dni: '12345678',
  phone: '987654321',
  email: 'ana@test.com',
  image: '',
  role: 'CIUDADANO',
  stateAccount: 'HABILITADO',
  averageScore: 0.0,
  alertsAttended: 0,
);

void main() {
  late MockLoginUseCase loginUseCase;
  late MockGetCurrentUserUseCase getCurrentUserUseCase;
  late MockSecureStorage storage;

  setUp(() {
    loginUseCase = MockLoginUseCase();
    getCurrentUserUseCase = MockGetCurrentUserUseCase();
    storage = MockSecureStorage();
  });

  AuthBloc buildBloc() => AuthBloc(
        loginUseCase: loginUseCase,
        getCurrentUserUseCase: getCurrentUserUseCase,
        storage: storage,
      );

  group('AuthSessionChecked — auto-login on app start', () {
    blocTest<AuthBloc, AuthState>(
      'goes to login when no session was saved (rememberMe off)',
      build: () {
        when(() => storage.isSessionSaved()).thenAnswer((_) async => false);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
      verify: (_) {
        verifyNever(() => getCurrentUserUseCase());
        verifyNever(() => storage.clearSession());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'goes to login when saved but there is no stored token/userId',
      build: () {
        when(() => storage.isSessionSaved()).thenAnswer((_) async => true);
        when(() => storage.getToken()).thenAnswer((_) async => null);
        when(() => storage.getUserId()).thenAnswer((_) async => null);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
      verify: (_) => verifyNever(() => getCurrentUserUseCase()),
    );

    blocTest<AuthBloc, AuthState>(
      'validates a stored session via GET /v1/auth/me and authenticates '
      'on success',
      build: () {
        when(() => storage.isSessionSaved()).thenAnswer((_) async => true);
        when(() => storage.getToken()).thenAnswer((_) async => 'token-1');
        when(() => storage.getUserId()).thenAnswer((_) async => 'u1');
        when(() => getCurrentUserUseCase())
            .thenAnswer((_) async => const Right(_user));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(user: _user, token: 'token-1'),
      ],
      verify: (_) => verifyNever(() => storage.clearSession()),
    );

    blocTest<AuthBloc, AuthState>(
      'clears the session and goes to login when /me is unrecoverable '
      '(401 after refresh failed)',
      build: () {
        when(() => storage.isSessionSaved()).thenAnswer((_) async => true);
        when(() => storage.getToken()).thenAnswer((_) async => 'token-1');
        when(() => storage.getUserId()).thenAnswer((_) async => 'u1');
        when(() => getCurrentUserUseCase()).thenAnswer(
          (_) async => const Left(UnauthorizedFailure('Session expired')),
        );
        when(() => storage.clearSession()).thenAnswer((_) async {});
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
      verify: (_) => verify(() => storage.clearSession()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'goes to login without clearing the session on a network error '
      '(so the next launch can retry)',
      build: () {
        when(() => storage.isSessionSaved()).thenAnswer((_) async => true);
        when(() => storage.getToken()).thenAnswer((_) async => 'token-1');
        when(() => storage.getUserId()).thenAnswer((_) async => 'u1');
        when(() => getCurrentUserUseCase())
            .thenAnswer((_) async => const Left(NetworkFailure()));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSessionChecked()),
      expect: () => [const AuthLoading(), const AuthUnauthenticated()],
      verify: (_) => verifyNever(() => storage.clearSession()),
    );
  });
}
