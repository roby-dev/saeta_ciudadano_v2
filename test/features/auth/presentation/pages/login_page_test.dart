import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/usecases/login_usecase.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:saeta_ciudadano_v2/features/auth/presentation/pages/login_page.dart';

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
    when(() => storage.saveSession(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
          rememberMe: any(named: 'rememberMe'),
        )).thenAnswer((_) async {});
  });

  AuthBloc buildBloc() => AuthBloc(
        loginUseCase: loginUseCase,
        getCurrentUserUseCase: getCurrentUserUseCase,
        storage: storage,
      );

  Future<void> pumpLogin(WidgetTester tester, AuthBloc bloc) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider.value(
            value: bloc,
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (_, __) => const Scaffold(body: Text('Register page')),
        ),
        GoRoute(
          path: '/main',
          builder: (_, __) => const Scaffold(body: Text('Main page')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  group('LoginPage', () {
    testWidgets('shows the Spanish brand header, labels and actions',
        (tester) async {
      final bloc = buildBloc();
      await pumpLogin(tester, bloc);

      expect(find.text('SAETA'), findsOneWidget);
      expect(find.text('Ciudadano · Seguridad ciudadana'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Ingresa con tu cuenta registrada.'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Recordarme'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ingresar'), findsOneWidget);
      expect(find.textContaining('¿No tienes cuenta?'), findsOneWidget);
      expect(find.text('Regístrate'), findsOneWidget);

      bloc.close();
    });

    testWidgets('shows Spanish validation errors when submitting empty',
        (tester) async {
      final bloc = buildBloc();
      await pumpLogin(tester, bloc);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pump();

      expect(find.text('El correo es obligatorio'), findsOneWidget);
      expect(find.text('La contraseña es obligatoria'), findsOneWidget);

      bloc.close();
    });

    testWidgets('shows a Spanish error for an invalid email', (tester) async {
      final bloc = buildBloc();
      await pumpLogin(tester, bloc);

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pump();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);

      bloc.close();
    });

    testWidgets(
        'submits with the entered credentials and shows the backend error '
        'in a dialog on failure', (tester) async {
      when(() => loginUseCase(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Left(UnauthorizedFailure(
            'Credenciales inválidas',
          )));
      final bloc = buildBloc();
      await pumpLogin(tester, bloc);

      await tester.enterText(
          find.byType(TextFormField).at(0), 'ana@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      verify(() => loginUseCase(
            email: 'ana@test.com',
            password: 'secret123',
          )).called(1);
      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cerrar'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Credenciales inválidas'), findsNothing);

      bloc.close();
    });

    testWidgets(
        'forwards remember-me and navigates to Main on successful login',
        (tester) async {
      when(() => loginUseCase(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async => const Right((token: 't1', refreshToken: 'r1', user: _user)),
      );
      final bloc = buildBloc();
      await pumpLogin(tester, bloc);

      await tester.enterText(
          find.byType(TextFormField).at(0), 'ana@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      verify(() => storage.saveSession(
            token: 't1',
            refreshToken: 'r1',
            userId: 'u1',
            rememberMe: true,
          )).called(1);
      expect(find.text('Main page'), findsOneWidget);

      bloc.close();
    });

    testWidgets('the register link navigates to the register page',
        (tester) async {
      final bloc = buildBloc();
      await pumpLogin(tester, bloc);

      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();

      expect(find.text('Register page'), findsOneWidget);

      bloc.close();
    });
  });
}
