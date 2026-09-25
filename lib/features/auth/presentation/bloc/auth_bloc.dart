import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/usecases/login_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required SecureStorage storage,
  })  : _loginUseCase = loginUseCase,
        _storage = storage,
        super(const AuthInitial()) {
    on<AuthLoginSubmitted>(_onLoginSubmitted);
    on<AuthSessionChecked>(_onSessionChecked);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final LoginUseCase _loginUseCase;
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

    final isSaved = await _storage.isSessionSaved();
    if (!isSaved) {
      emit(const AuthUnauthenticated());
      return;
    }

    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    // Token exists and remember me is on — go to main without re-login.
    // Full token renewal goes in a later iteration.
    emit(const AuthUnauthenticated()); // Navigate to login for now
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _storage.clearSession();
    emit(const AuthUnauthenticated());
  }
}
