import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/register/domain/entities/person_entity.dart';
import 'package:saeta_ciudadano_v2/features/register/domain/usecases/lookup_dni_usecase.dart';
import 'package:saeta_ciudadano_v2/features/register/domain/usecases/register_usecase.dart';
import 'package:saeta_ciudadano_v2/features/register/presentation/bloc/register_bloc.dart';
import 'package:saeta_ciudadano_v2/features/register/presentation/pages/register_page.dart';

class MockLookupDniUseCase extends Mock implements LookupDniUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

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
  late MockLookupDniUseCase lookupDniUseCase;
  late MockRegisterUseCase registerUseCase;
  late MockSecureStorage storage;

  setUp(() {
    lookupDniUseCase = MockLookupDniUseCase();
    registerUseCase = MockRegisterUseCase();
    storage = MockSecureStorage();
    when(() => storage.saveSession(
          token: any(named: 'token'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
          rememberMe: any(named: 'rememberMe'),
        )).thenAnswer((_) async {});
  });

  RegisterBloc buildBloc() => RegisterBloc(
        lookupDniUseCase: lookupDniUseCase,
        registerUseCase: registerUseCase,
        storage: storage,
      );

  Future<void> pumpRegister(WidgetTester tester, RegisterBloc bloc) async {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(
          path: '/register',
          builder: (_, __) => BlocProvider.value(
            value: bloc,
            child: const RegisterPage(),
          ),
        ),
        GoRoute(
          path: '/main',
          builder: (_, __) => const Scaffold(body: Text('Main page')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  group('RegisterPage', () {
    testWidgets('shows the Spanish header, field labels and actions',
        (tester) async {
      final bloc = buildBloc();
      await pumpRegister(tester, bloc);

      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Apellido'), findsOneWidget);
      expect(find.text('DNI'), findsOneWidget);
      expect(find.text('Teléfono'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Confirmar contraseña'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Registrarme'), findsOneWidget);
      expect(find.textContaining('¿Ya tienes cuenta?'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsOneWidget);

      bloc.close();
    });

    testWidgets('shows Spanish validation errors when submitting empty',
        (tester) async {
      final bloc = buildBloc();
      await pumpRegister(tester, bloc);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Registrarme'));
      await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
      await tester.pump();

      expect(find.text('El DNI es obligatorio'), findsOneWidget);
      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(find.text('El apellido es obligatorio'), findsOneWidget);
      expect(find.text('El teléfono es obligatorio'), findsOneWidget);
      expect(find.text('La contraseña es obligatoria'), findsOneWidget);
      expect(find.text('Confirma tu contraseña'), findsOneWidget);

      bloc.close();
    });

    testWidgets('shows a Spanish mismatch error for confirm password',
        (tester) async {
      final bloc = buildBloc();
      await pumpRegister(tester, bloc);

      final passwordField = find.descendant(
        of: find.byKey(const Key('registerPasswordField')),
        matching: find.byType(TextFormField),
      );
      final confirmField = find.descendant(
        of: find.byKey(const Key('registerConfirmPasswordField')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(passwordField, 'secret123');
      await tester.enterText(confirmField, 'different1');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Registrarme'));
      await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

      bloc.close();
    });

    testWidgets('auto-fills name/lastname on a found DNI lookup',
        (tester) async {
      when(() => lookupDniUseCase('12345678')).thenAnswer(
        (_) async => const Right(PersonEntity(names: 'Ana', lastname: 'Lopez')),
      );
      final bloc = buildBloc();
      await pumpRegister(tester, bloc);

      final dniField = find.descendant(
        of: find.byKey(const Key('registerDniField')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dniField, '12345678');
      await tester.pump();

      verify(() => lookupDniUseCase('12345678')).called(1);

      final nameField = tester.widget<TextFormField>(find.descendant(
        of: find.byKey(const Key('registerNameField')),
        matching: find.byType(TextFormField),
      ));
      expect(nameField.controller?.text, 'Ana');

      bloc.close();
    });

    testWidgets(
        'submits and navigates to Main with the entered data on success',
        (tester) async {
      when(() => registerUseCase(
            dni: any(named: 'dni'),
            name: any(named: 'name'),
            lastname: any(named: 'lastname'),
            phone: any(named: 'phone'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer(
        (_) async =>
            const Right((token: 't1', refreshToken: 'r1', user: _user)),
      );
      final bloc = buildBloc();
      await pumpRegister(tester, bloc);

      Finder fieldFor(String key) => find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextFormField),
          );

      when(() => lookupDniUseCase('12345678')).thenAnswer(
        (_) async => const Right(PersonEntity(names: 'Ana', lastname: 'Lopez')),
      );
      await tester.enterText(fieldFor('registerDniField'), '12345678');
      await tester.pump();
      await tester.enterText(fieldFor('registerPhoneField'), '987654321');
      await tester.enterText(fieldFor('registerPasswordField'), 'secret123');
      await tester.enterText(
          fieldFor('registerConfirmPasswordField'), 'secret123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Registrarme'));
      await tester.tap(find.widgetWithText(FilledButton, 'Registrarme'));
      await tester.pumpAndSettle();

      expect(find.text('Main page'), findsOneWidget);

      bloc.close();
    });

    testWidgets('the login link navigates back', (tester) async {
      final bloc = buildBloc();
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('Login page')),
          ),
          GoRoute(
            path: '/register',
            builder: (context, __) => BlocProvider.value(
              value: bloc,
              child: const RegisterPage(),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/register');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inicia sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Login page'), findsOneWidget);

      bloc.close();
    });
  });
}
