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
}
