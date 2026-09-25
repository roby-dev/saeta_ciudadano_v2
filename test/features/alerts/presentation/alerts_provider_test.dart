import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/core/realtime/realtime_service.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/entities/citizen_alert_entity.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/get_user_alerts_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/domain/usecases/send_alert_feedback_usecase.dart';
import 'package:saeta_ciudadano_v2/features/alerts/presentation/providers/alerts_provider.dart';

class MockGetUserAlertsUseCase extends Mock implements GetUserAlertsUseCase {}

class MockSendAlertFeedbackUseCase extends Mock
    implements SendAlertFeedbackUseCase {}

class MockRealtimeService extends Mock implements RealtimeService {}

const _alert = CitizenAlertEntity(
  id: 'a1',
  userId: 'u1',
  latitude: -12.0,
  longitude: -77.0,
  typeName: 'Robo',
  stateName: 'Pendiente',
  creationDate: '2026-01-01T00:00:00.000Z',
);

/// A fresh growable list each call: `AlertsProvider.loadAlerts` sorts the
/// list it receives in place, so it must never be a `const`/fixed list.
Either<Failure, List<CitizenAlertEntity>> _oneAlertResult() {
  final alerts = List<CitizenAlertEntity>.generate(1, (_) => _alert);
  return Right<Failure, List<CitizenAlertEntity>>(alerts);
}

void main() {
  late MockGetUserAlertsUseCase getUserAlertsUseCase;
  late MockSendAlertFeedbackUseCase sendAlertFeedbackUseCase;
  late MockRealtimeService realtimeService;
  late StreamController<Map<String, dynamic>> updatedAlertsController;
  late AlertsProvider provider;

  setUp(() {
    getUserAlertsUseCase = MockGetUserAlertsUseCase();
    sendAlertFeedbackUseCase = MockSendAlertFeedbackUseCase();
    realtimeService = MockRealtimeService();
    updatedAlertsController = StreamController<Map<String, dynamic>>.broadcast();

    when(() => realtimeService.updatedAlerts)
        .thenAnswer((_) => updatedAlertsController.stream);
    when(() => getUserAlertsUseCase('u1'))
        .thenAnswer((_) async => _oneAlertResult());

    provider = AlertsProvider(
      getUserAlertsUseCase: getUserAlertsUseCase,
      sendAlertFeedbackUseCase: sendAlertFeedbackUseCase,
      realtimeService: realtimeService,
    );
  });

  tearDown(() async {
    await updatedAlertsController.close();
  });

  test('an updatedAlert event refreshes the alerts already loaded for a user',
      () async {
    await provider.loadAlerts('u1');
    clearInteractions(getUserAlertsUseCase);
    when(() => getUserAlertsUseCase('u1'))
        .thenAnswer((_) async => _oneAlertResult());

    updatedAlertsController.add({'id': 'a1', 'userId': 'u1'});
    await Future<void>.delayed(Duration.zero);

    verify(() => getUserAlertsUseCase('u1')).called(1);
  });

  test('an updatedAlert event before any load is a no-op', () async {
    updatedAlertsController.add({'id': 'a1', 'userId': 'u1'});
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => getUserAlertsUseCase(any()));
  });

  test('dispose cancels the realtime subscription', () async {
    await provider.loadAlerts('u1');
    clearInteractions(getUserAlertsUseCase);

    provider.dispose();
    updatedAlertsController.add({'id': 'a1', 'userId': 'u1'});
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => getUserAlertsUseCase(any()));
  });
}
