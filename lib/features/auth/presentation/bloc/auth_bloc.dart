import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required SecureStorage storage,
  })  : _loginUseCase = loginUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _storage = storage,
        super(const AuthInitial()) {
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthSessionChecked>(_onSessionChecked);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final LoginUseCase _loginUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final SecureStorage _storage;

  Future<void> _onLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _loginUseCase(
      email: event.email,
      password: event.password,
    );

    await result.fold(
      (failure) async => emit(AuthFailure(failure.message)),
      (data) async {
        await _storage.saveSession(
          token: data.token,
          refreshToken: data.refreshToken,
          userId: data.user.id,
          rememberMe: event.rememberMe,
        );
        emit(AuthAuthenticated(user: data.user, token: data.token));
      },
    );
  }

  Future<void> _onSessionChecked(
    AuthSessionChecked event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    // No rememberMe (or nothing saved) always goes to login, regardless of
    // any leftover token — matches SecureStorage.isSessionSaved semantics.
    final isSaved = await _storage.isSessionSaved();
    if (!isSaved) {
      emit(const AuthUnauthenticated());
      return;
    }

    final token = await _storage.getToken();
    final userId = await _storage.getUserId();
    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    // Validate the stored session against the backend. This goes through
    // the app's normal Dio, so AuthInterceptor transparently refreshes an
    // expired access token before this ever surfaces as a failure here.
    final result = await _getCurrentUserUseCase();
    await result.fold(
      (failure) async {
        if (failure is UnauthorizedFailure) {
          // Session is unrecoverable (401 even after a refresh attempt,
          // or no valid refresh token): clear it so login starts clean.
          await _storage.clearSession();
        }
        // Any other failure (network error, server error) leaves the
        // stored session untouched — a transient outage shouldn't log
        // the user out; the next launch can retry the same session. See
        // the feature doc's T6 decision gap for this assumption.
        emit(const AuthUnauthenticated());
      },
      (user) async {
        emit(AuthAuthenticated(user: user, token: token));
      },
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _storage.clearSession();
    emit(const AuthUnauthenticated());
  }
}
