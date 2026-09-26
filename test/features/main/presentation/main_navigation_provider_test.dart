import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/providers/main_navigation_provider.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

class MockRealtimeService extends Mock implements RealtimeService {}

UserEntity _buildUser({required String id, String name = 'Old Name'}) {
  return UserEntity(
    id: id,
    name: name,
    lastname: 'Last',
    dni: '12345678',
    phone: '999999999',
    email: 'user@test.com',
    image: 'img.png',
    role: 'CIUDADANO',
    stateAccount: 'HABILITADO',
    averageScore: 4.5,
    alertsAttended: 3,
  );
}

void main() {
  late MockSecureStorage storage;
  late MockRealtimeService realtimeService;
  late StreamController<Map<String, dynamic>> profileController;
  late MainNavigationProvider provider;

  setUp(() {
    storage = MockSecureStorage();
    realtimeService = MockRealtimeService();
    profileController = StreamController<Map<String, dynamic>>.broadcast();
    when(() => storage.clearSession()).thenAnswer((_) async {});
    when(() => realtimeService.disconnect()).thenAnswer((_) async {});
    when(() => realtimeService.updatedProfiles)
        .thenAnswer((_) => profileController.stream);

    provider = MainNavigationProvider(
      storage: storage,
      realtimeService: realtimeService,
    );
  });

  tearDown(() {
    profileController.close();
  });

  test('logout clears the session and disconnects the realtime service',
      () async {
    await provider.logout();

    verify(() => storage.clearSession()).called(1);
    verify(() => realtimeService.disconnect()).called(1);
  });

  group('updatedProfile', () {
    test(
        'replaces currentUser when the payload id matches, preserving '
        'fields absent from the payload', () async {
      final user = _buildUser(id: 'u1');
      provider = MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
        initialUser: user,
      );

      profileController.add({'id': 'u1', 'name': 'New Name'});
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser?.name, 'New Name');
      expect(provider.currentUser?.lastname, user.lastname);
      expect(provider.currentUser?.averageScore, user.averageScore);
      expect(provider.currentUser?.alertsAttended, user.alertsAttended);
      expect(provider.currentUser?.stateAccount, user.stateAccount);
    });

    test('ignores an event whose id does not match the current user',
        () async {
      final user = _buildUser(id: 'u1');
      provider = MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
        initialUser: user,
      );

      profileController.add({'id': 'other-user', 'name': 'New Name'});
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser, user);
    });

    test('ignores the event when there is no current user', () async {
      provider = MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
      );

      profileController.add({'id': 'u1', 'name': 'New Name'});
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser, isNull);
    });

    test('cancels the subscription on dispose', () async {
      final user = _buildUser(id: 'u1');
      provider = MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
        initialUser: user,
      );

      provider.dispose();
      // A notifyListeners() call after dispose() throws in debug mode, so
      // the absence of an exception here proves the subscription was
      // cancelled rather than still delivering into a disposed provider.
      profileController.add({'id': 'u1', 'name': 'New Name'});
      await Future<void>.delayed(Duration.zero);
    });
  });
}
