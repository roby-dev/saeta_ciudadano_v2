import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/get_user_alerts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/send_alert_feedback_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/providers/alerts_provider.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/widgets/alert_detail_sheet.dart';

class MockGetUserAlertsUseCase extends Mock implements GetUserAlertsUseCase {}

class MockSendAlertFeedbackUseCase extends Mock
    implements SendAlertFeedbackUseCase {}

class MockRealtimeService extends Mock implements RealtimeService {}

const _pending = CitizenAlertEntity(
  id: 'abcdef123456',
  userId: 'u1',
  latitude: -12.0,
  longitude: -77.0,
  typeName: 'Robo',
  stateName: 'Pendiente',
  creationDate: '2026-09-20T10:00:00.000Z',
);

const _inProcess = CitizenAlertEntity(
  id: 'abcdef789012',
  userId: 'u1',
  latitude: -12.0,
  longitude: -77.0,
  typeName: 'Incendio',
  stateName: 'En Proceso',
  creationDate: '2026-09-20T10:00:00.000Z',
  attentionDate: '2026-09-20T10:30:00.000Z',
  attendedByName: 'Juan Perez',
  attendedByPhone: '987654321',
);

const _resolved = CitizenAlertEntity(
  id: '',
  userId: 'u1',
  latitude: -12.0,
  longitude: -77.0,
  typeName: 'Robo',
  stateName: 'Resuelta',
  creationDate: '2026-09-20T10:00:00.000Z',
  attentionDate: '2026-09-20T10:30:00.000Z',
  culminationDate: '2026-09-20T11:00:00.000Z',
  attendedByName: 'Juan Perez',
  attendedByPhone: '987654321',
);

const _cancelled = CitizenAlertEntity(
  id: 'x1',
  userId: 'u1',
  latitude: -12.0,
  longitude: -77.0,
  typeName: 'Robo',
  stateName: 'Cancelada',
  creationDate: '2026-09-20T10:00:00.000Z',
  culminationDate: '2026-09-20T11:00:00.000Z',
);

void main() {
  late MockGetUserAlertsUseCase getUserAlertsUseCase;
  late MockSendAlertFeedbackUseCase sendAlertFeedbackUseCase;
  late MockRealtimeService realtimeService;
  late AlertsProvider provider;

  setUp(() {
    getUserAlertsUseCase = MockGetUserAlertsUseCase();
    sendAlertFeedbackUseCase = MockSendAlertFeedbackUseCase();
    realtimeService = MockRealtimeService();
    when(() => realtimeService.updatedAlerts)
        .thenAnswer((_) => const Stream.empty());
    provider = AlertsProvider(
      getUserAlertsUseCase: getUserAlertsUseCase,
      sendAlertFeedbackUseCase: sendAlertFeedbackUseCase,
      realtimeService: realtimeService,
    );
  });

  Future<void> pumpSheet(WidgetTester tester, CitizenAlertEntity alert) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AlertDetailSheet.show(context, alert),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('summary card', () {
    testWidgets('shows the type name and short id', (tester) async {
      await pumpSheet(tester, _pending);

      expect(find.text('Robo'), findsOneWidget);
      expect(find.text('#123456'), findsOneWidget);
    });

    testWidgets('shows the state pill (no collision with the timeline\'s '
        'own "Pendiente" wording, since this alert is in process)',
        (tester) async {
      await pumpSheet(tester, _inProcess);

      expect(find.text('En Proceso'), findsOneWidget);
    });

    testWidgets('hides the short id when the alert has no id', (tester) async {
      await pumpSheet(tester, _resolved);

      expect(find.textContaining('#'), findsNothing);
    });
  });

  group('Seguimiento timeline', () {
    testWidgets('a pending alert shows "Pendiente" for the two remaining '
        'steps', (tester) async {
      await pumpSheet(tester, _pending);

      expect(find.text('Seguimiento'), findsOneWidget);
      expect(find.text('Reportada'), findsOneWidget);
      expect(find.text('En atención'), findsOneWidget);
      // 2 timeline steps not yet reached + the state pill itself (also
      // "Pendiente" for this alert) = 3.
      expect(find.text('Pendiente'), findsNWidgets(3));
    });

    testWidgets('a resolved alert shows dates for all 3 steps and the final '
        'step labeled "Resuelta"', (tester) async {
      await pumpSheet(tester, _resolved);

      expect(find.text('Pendiente'), findsNothing);
      expect(find.text('Resuelta'), findsWidgets);
    });

    testWidgets('a cancelled alert labels the final step "Cancelada"',
        (tester) async {
      await pumpSheet(tester, _cancelled);

      expect(find.text('Cancelada'), findsWidgets);
    });
  });

  group('Datos de la atención', () {
    testWidgets('shows the GPS coordinates unconditionally', (tester) async {
      await pumpSheet(tester, _pending);

      expect(find.text('Ubicación GPS'), findsOneWidget);
      expect(find.text('-12.000000, -77.000000'), findsOneWidget);
    });

    testWidgets('hides the attention person/phone rows when not set',
        (tester) async {
      await pumpSheet(tester, _pending);

      expect(find.text('Personal que atendió'), findsNothing);
      expect(find.text('Teléfono de contacto'), findsNothing);
    });

    testWidgets('shows the attention person and a call button for the '
        'phone when set', (tester) async {
      await pumpSheet(tester, _inProcess);

      expect(find.text('Personal que atendió'), findsOneWidget);
      expect(find.text('Juan Perez'), findsOneWidget);
      expect(find.text('Teléfono de contacto'), findsOneWidget);
      expect(find.text('987654321'), findsOneWidget);
      expect(find.byKey(const ValueKey('attention-call-button')),
          findsOneWidget);

      // Best-effort tel: launch — must never throw even without a
      // registered url_launcher platform channel under `flutter test`.
      await tester.ensureVisible(
        find.byKey(const ValueKey('attention-call-button')),
      );
      await tester.tap(find.byKey(const ValueKey('attention-call-button')));
      await tester.pump();
    });
  });

  group('rating card', () {
    testWidgets('is hidden for a non-resolved alert', (tester) async {
      await pumpSheet(tester, _pending);

      expect(find.text('Enviar calificación'), findsNothing);
    });

    testWidgets('is shown for a resolved alert with 5 star targets and the '
        'comment field', (tester) async {
      await pumpSheet(tester, _resolved);

      expect(find.text('Enviar calificación'), findsOneWidget);
      expect(find.text('Comentario (opcional)'), findsOneWidget);
    });

    testWidgets('submitting shows the thanks message on success',
        (tester) async {
      when(() => sendAlertFeedbackUseCase(
            alertId: any(named: 'alertId'),
            commentary: any(named: 'commentary'),
            score: any(named: 'score'),
          )).thenAnswer((_) async => const Right(_resolved));
      await pumpSheet(tester, _resolved);

      await tester.ensureVisible(find.text('Enviar calificación'));
      await tester.tap(find.text('Enviar calificación'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('¡Gracias por calificar la atención recibida!'),
        findsOneWidget,
      );
    });

    testWidgets('submitting shows the error message on failure',
        (tester) async {
      when(() => sendAlertFeedbackUseCase(
            alertId: any(named: 'alertId'),
            commentary: any(named: 'commentary'),
            score: any(named: 'score'),
          )).thenAnswer(
        (_) async => const Left(ServerFailure('No se pudo calificar')),
      );
      await pumpSheet(tester, _resolved);

      await tester.ensureVisible(find.text('Enviar calificación'));
      await tester.tap(find.text('Enviar calificación'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No se pudo calificar'), findsOneWidget);
    });
  });
}
