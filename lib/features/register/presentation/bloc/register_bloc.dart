import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/usecases/lookup_dni_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'register_event.dart';
import 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc({
    required LookupDniUseCase lookupDniUseCase,
    required RegisterUseCase registerUseCase,
    required SecureStorage storage,
  })  : _lookupDni = lookupDniUseCase,
        _register = registerUseCase,
        _storage = storage,
        super(const RegisterInitial()) {
    on<RegisterDniChanged>(_onDniChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  final LookupDniUseCase _lookupDni;
  final RegisterUseCase _register;
  final SecureStorage _storage;

  Future<void> _onDniChanged(
    RegisterDniChanged event,
    Emitter<RegisterState> emit,
  ) async {
    if (event.dni.length != 8) {
      // Clear auto-fill when DNI is incomplete
      if (state is RegisterDniFound) emit(const RegisterInitial());
      return;
    }

    emit(const RegisterDniLookingUp());
    final result = await _lookupDni(event.dni);
    result.fold(
      (failure) => emit(RegisterDniNotFound(failure.message)),
      (person) => emit(
        RegisterDniFound(names: person.names, lastname: person.lastname),
      ),
    );
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const RegisterLoading());

    final result = await _register(
      dni: event.dni,
      name: event.name,
      lastname: event.lastname,
      phone: event.phone,
      email: event.email,
      password: event.password,
    );

    await result.fold(
      (failure) async => emit(RegisterFailure(failure.message)),
      (data) async {
        await _storage.saveSession(
          token: data.token,
          refreshToken: data.refreshToken,
          userId: data.user.id,
          rememberMe: true,
        );
        emit(RegisterSuccess(user: data.user, token: data.token));
      },
    );
  }
}
