import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/constants/app_constants.dart';
import 'package:saeta_ciudadano_v2/core/storage/secure_storage.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage flutterSecureStorage;
  late SecureStorage secureStorage;

  setUp(() {
    flutterSecureStorage = MockFlutterSecureStorage();
    secureStorage = SecureStorage(flutterSecureStorage);
  });

  group('updateTokens', () {
    test('writes the access token and refresh token', () async {
      when(() => flutterSecureStorage.write(
            key: AppConstants.keyToken,
            value: 'new-access',
          )).thenAnswer((_) async {});
      when(() => flutterSecureStorage.write(
            key: AppConstants.keyRefreshToken,
            value: 'new-refresh',
          )).thenAnswer((_) async {});

      await secureStorage.updateTokens(
        token: 'new-access',
        refreshToken: 'new-refresh',
      );

      verify(() => flutterSecureStorage.write(
            key: AppConstants.keyToken,
            value: 'new-access',
          )).called(1);
      verify(() => flutterSecureStorage.write(
            key: AppConstants.keyRefreshToken,
            value: 'new-refresh',
          )).called(1);
    });

    test('does not touch userId or rememberMe', () async {
      when(() => flutterSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await secureStorage.updateTokens(
        token: 'new-access',
        refreshToken: 'new-refresh',
      );

      verifyNever(() => flutterSecureStorage.write(
            key: AppConstants.keyUserId,
            value: any(named: 'value'),
          ));
      verifyNever(() => flutterSecureStorage.write(
            key: AppConstants.keyRememberMe,
            value: any(named: 'value'),
          ));
    });
  });

  group('sendSmsOnAlert preference', () {
    test('setSendSmsOnAlert writes the flag as a string', () async {
      when(() => flutterSecureStorage.write(
            key: AppConstants.keySendSmsOnAlert,
            value: 'true',
          )).thenAnswer((_) async {});

      await secureStorage.setSendSmsOnAlert(true);

      verify(() => flutterSecureStorage.write(
            key: AppConstants.keySendSmsOnAlert,
            value: 'true',
          )).called(1);
    });

    test('getSendSmsOnAlert returns true when stored value is "true"',
        () async {
      when(() => flutterSecureStorage.read(
            key: AppConstants.keySendSmsOnAlert,
          )).thenAnswer((_) async => 'true');

      expect(await secureStorage.getSendSmsOnAlert(), isTrue);
    });

    test('getSendSmsOnAlert defaults to false when nothing is stored',
        () async {
      when(() => flutterSecureStorage.read(
            key: AppConstants.keySendSmsOnAlert,
          )).thenAnswer((_) async => null);

      expect(await secureStorage.getSendSmsOnAlert(), isFalse);
    });
  });

  group('clearSession', () {
    test('deletes the session keys', () async {
      when(() => flutterSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
      when(() => flutterSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await secureStorage.clearSession();

      verify(() => flutterSecureStorage.delete(key: AppConstants.keyToken))
          .called(1);
      verify(() => flutterSecureStorage.delete(
          key: AppConstants.keyRefreshToken)).called(1);
      verify(() => flutterSecureStorage.delete(key: AppConstants.keyUserId))
          .called(1);
      verify(() => flutterSecureStorage.delete(
          key: AppConstants.keyRememberMe)).called(1);
    });

    test('resets the local send-SMS-on-alert preference to false', () async {
      when(() => flutterSecureStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
      when(() => flutterSecureStorage.write(
            key: AppConstants.keySendSmsOnAlert,
            value: 'false',
          )).thenAnswer((_) async {});

      await secureStorage.clearSession();

      verify(() => flutterSecureStorage.write(
            key: AppConstants.keySendSmsOnAlert,
            value: 'false',
          )).called(1);
    });
  });
}
