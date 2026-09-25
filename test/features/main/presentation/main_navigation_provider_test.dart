import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/providers/main_navigation_provider.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

class MockRealtimeService extends Mock implements RealtimeService {}

void main() {
  late MockSecureStorage storage;
  late MockRealtimeService realtimeService;
  late MainNavigationProvider provider;

  setUp(() {
    storage = MockSecureStorage();
    realtimeService = MockRealtimeService();
    when(() => storage.clearSession()).thenAnswer((_) async {});
    when(() => realtimeService.disconnect()).thenAnswer((_) async {});

    provider = MainNavigationProvider(
      storage: storage,
      realtimeService: realtimeService,
    );
  });

  test('logout clears the session and disconnects the realtime service',
      () async {
    await provider.logout();

    verify(() => storage.clearSession()).called(1);
    verify(() => realtimeService.disconnect()).called(1);
  });
}
