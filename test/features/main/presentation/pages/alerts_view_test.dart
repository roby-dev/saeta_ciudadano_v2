import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/get_user_alerts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/send_alert_feedback_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/providers/alerts_provider.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/pages/alerts_view.dart';
import 'package:saeta_ciudadano_v2/features/main/presentation/providers/main_navigation_provider.dart';

class MockGetUserAlertsUseCase extends Mock implements GetUserAlertsUseCase {}

class MockSendAlertFeedbackUseCase extends Mock
    implements SendAlertFeedbackUseCase {}

class MockRealtimeService extends Mock implements RealtimeService {}

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

/// A fresh growable empty list each call: `AlertsProvider.loadAlerts` sorts
/// the list it receives in place (same convention as
/// `alerts_provider_test.dart`'s `_oneAlertResult`), so a `const []` literal
/// (which `flutter analyze` would otherwise suggest) would throw.
List<CitizenAlertEntity> _noAlerts() => <CitizenAlertEntity>[];

CitizenAlertEntity _alert(String id, String typeName, String stateName) =>
    CitizenAlertEntity(
      id: id,
      userId: 'u1',
      latitude: -12.0,
      longitude: -77.0,
      typeName: typeName,
      stateName: stateName,
      creationDate: '2026-09-20T10:00:00.000Z',
    );

void main() {
  late MockGetUserAlertsUseCase getUserAlertsUseCase;
  late MockSendAlertFeedbackUseCase sendAlertFeedbackUseCase;
  late MockRealtimeService realtimeService;
  late MockSecureStorage storage;

  setUp(() {
    getUserAlertsUseCase = MockGetUserAlertsUseCase();
    sendAlertFeedbackUseCase = MockSendAlertFeedbackUseCase();
    realtimeService = MockRealtimeService();
    storage = MockSecureStorage();
    when(() => realtimeService.updatedAlerts)
        .thenAnswer((_) => const Stream.empty());
    when(() => realtimeService.updatedProfiles)
        .thenAnswer((_) => const Stream.empty());
  });

  AlertsProvider buildAlertsProvider() => AlertsProvider(
        getUserAlertsUseCase: getUserAlertsUseCase,
        sendAlertFeedbackUseCase: sendAlertFeedbackUseCase,
        realtimeService: realtimeService,
      );

  MainNavigationProvider buildNavProvider() => MainNavigationProvider(
        storage: storage,
        realtimeService: realtimeService,
        initialUser: _user,
      );

  Future<void> pumpView(WidgetTester tester, AlertsProvider provider) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider.value(value: buildNavProvider()),
        ],
        child: const MaterialApp(home: AlertsView()),
      ),
    );
  }

  group('AlertsView header', () {
    testWidgets('shows the title and the live-update subtitle',
        (tester) async {
      when(() => getUserAlertsUseCase('u1'))
          .thenAnswer((_) async => Right(_noAlerts()));
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Mis alertas'), findsOneWidget);
      expect(find.text('Actualización en tiempo real'), findsOneWidget);
    });

    testWidgets('the refresh button calls refreshAlerts', (tester) async {
      when(() => getUserAlertsUseCase('u1'))
          .thenAnswer((_) async => Right(_noAlerts()));
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();
      clearInteractions(getUserAlertsUseCase);
      when(() => getUserAlertsUseCase('u1'))
          .thenAnswer((_) async => Right(_noAlerts()));

      await tester.tap(find.widgetWithIcon(IconButton, Icons.refresh_rounded));
      await tester.pumpAndSettle();

      verify(() => getUserAlertsUseCase('u1')).called(1);
    });
  });

  group('AlertsView summary + grouping', () {
    testWidgets('summary tiles show total/active/resolved counts and '
        'sections group alerts correctly', (tester) async {
      when(() => getUserAlertsUseCase('u1')).thenAnswer(
        (_) async => Right([
          _alert('1', 'Robo', 'Pendiente'),
          _alert('2', 'Incendio', 'En Proceso'),
          _alert('3', 'Robo', 'Resuelta'),
          _alert('4', 'Robo', 'Cancelada'),
        ]),
      );
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Activas'), findsWidgets); // tile label + section
      expect(find.text('Resueltas'), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // total
      expect(find.text('2'), findsOneWidget); // active (pending+in-process)
      expect(find.text('1'), findsOneWidget); // resolved

      expect(find.text('Historial'), findsOneWidget);
    });

    testWidgets('hides the Activas section when there are no active alerts',
        (tester) async {
      when(() => getUserAlertsUseCase('u1')).thenAnswer(
        (_) async => Right([_alert('1', 'Robo', 'Resuelta')]),
      );
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
      // Only the summary tile's "Activas" label remains, no section header
      // (the section header would be a duplicate of the same text, so
      // check there's exactly one — the tile).
      expect(find.text('Activas'), findsOneWidget);
    });

    testWidgets('hides the Historial section when there is no history',
        (tester) async {
      when(() => getUserAlertsUseCase('u1')).thenAnswer(
        (_) async => Right([_alert('1', 'Robo', 'Pendiente')]),
      );
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsNothing);
    });
  });

  group('AlertsView states', () {
    testWidgets('shows the loading message while loading', (tester) async {
      when(() => getUserAlertsUseCase('u1')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Right(_noAlerts());
      });
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pump();

      expect(find.text('Cargando historial de alertas...'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows the error message and Reintentar on failure',
        (tester) async {
      when(() => getUserAlertsUseCase('u1')).thenAnswer(
        (_) async => const Left(ServerFailure('boom')),
      );
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('No se pudieron cargar las alertas'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('shows the empty state message when there are no alerts',
        (tester) async {
      when(() => getUserAlertsUseCase('u1'))
          .thenAnswer((_) async => Right(_noAlerts()));
      final provider = buildAlertsProvider();
      await pumpView(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('No tienes alertas registradas'), findsOneWidget);
    });
  });
}
