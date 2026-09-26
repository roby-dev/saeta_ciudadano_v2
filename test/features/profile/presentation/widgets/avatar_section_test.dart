import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_file_validator.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_image_picker.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:saeta_ciudadano_v2/features/profile/presentation/widgets/avatar_section.dart';
import 'package:saeta_ciudadano_v2/service_locator.dart';

class MockUploadAvatarUseCase extends Mock implements UploadAvatarUseCase {}

class MockAvatarImagePicker extends Mock implements AvatarImagePicker {}

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
  setUp(() {
    sl.registerLazySingleton<UploadAvatarUseCase>(
      () => MockUploadAvatarUseCase(),
    );
    sl.registerLazySingleton<AvatarImagePicker>(() => MockAvatarImagePicker());
    sl.registerLazySingleton<AvatarFileValidator>(
      () => const AvatarFileValidator(),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpAvatar(WidgetTester tester, UserEntity? user) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarSection(user: user, onUpdated: (_) {}),
        ),
      ),
    );
  }

  testWidgets('shows the 2-letter initials placeholder when there is no '
      'photo', (tester) async {
    await pumpAvatar(tester, _user);
    await tester.pump();

    expect(find.text('AL'), findsOneWidget);
  });

  testWidgets('shows a camera badge button', (tester) async {
    await pumpAvatar(tester, _user);
    await tester.pump();

    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('tapping the avatar opens the camera/gallery picker sheet',
      (tester) async {
    await pumpAvatar(tester, _user);
    await tester.pump();

    await tester.tap(find.text('AL'));
    await tester.pumpAndSettle();

    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de galería'), findsOneWidget);
  });
}
