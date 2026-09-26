import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/emergency_contacts/domain/services/peruvian_phone_normalizer.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:saeta_ciudadano_v2/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:saeta_ciudadano_v2/service_locator.dart';

class MockUpdateProfileUseCase extends Mock implements UpdateProfileUseCase {}

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

const _updatedUser = UserEntity(
  id: 'u1',
  name: 'Ana María',
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
  late MockUpdateProfileUseCase updateProfileUseCase;

  setUp(() {
    updateProfileUseCase = MockUpdateProfileUseCase();
    sl.registerLazySingleton<UpdateProfileUseCase>(() => updateProfileUseCase);
    sl.registerLazySingleton<PeruvianPhoneNormalizer>(
      () => const PeruvianPhoneNormalizer(),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpEdit(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: ProfileEditPage(user: _user, onUpdated: (_) {}),
      ),
    );
  }

  testWidgets('shows the primary app bar title and Spanish labels above '
      'each field', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Apellido'), findsOneWidget);
    expect(find.text('Teléfono'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
  });

  testWidgets('shows "Guardando..." while saving is in flight',
      (tester) async {
    final completer = Completer<Either<Failure, UserEntity>>();
    when(() => updateProfileUseCase(
          any(),
          name: any(named: 'name'),
          lastname: any(named: 'lastname'),
          phone: any(named: 'phone'),
          email: any(named: 'email'),
        )).thenAnswer((_) => completer.future);
    await pumpEdit(tester);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();

    expect(find.text('Guardando...'), findsOneWidget);

    completer.complete(const Right(_updatedUser));
    await tester.pumpAndSettle();
  });
}
