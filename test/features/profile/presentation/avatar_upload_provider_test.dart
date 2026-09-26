import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:saeta_ciudadano_v2/core/errors/failure.dart';
import 'package:saeta_ciudadano_v2/features/auth/domain/entities/user_entity.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_file_validator.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/services/avatar_image_picker.dart';
import 'package:saeta_ciudadano_v2/features/profile/domain/usecases/upload_avatar_usecase.dart';
import 'package:saeta_ciudadano_v2/features/profile/presentation/providers/avatar_upload_provider.dart';

class MockUploadAvatarUseCase extends Mock implements UploadAvatarUseCase {}

class MockAvatarImagePicker extends Mock implements AvatarImagePicker {}

const _updatedUser = UserEntity(
  id: 'u1',
  name: 'Ana',
  lastname: 'Torres',
  dni: '12345678',
  phone: '987654321',
  email: 'ana@example.com',
  image: 'new-file-id.jpg',
  role: 'CIUDADANO',
  stateAccount: 'HABILITADO',
  averageScore: 0,
  alertsAttended: 0,
);

void main() {
  late MockUploadAvatarUseCase useCase;
  late MockAvatarImagePicker picker;
  UserEntity? capturedByCallback;

  AvatarUploadProvider buildProvider({
    AvatarFileValidator validator = const AvatarFileValidator(),
    Future<int> Function(String path)? fileSizeReader,
  }) {
    return AvatarUploadProvider(
      uploadAvatarUseCase: useCase,
      imagePicker: picker,
      fileValidator: validator,
      userId: 'u1',
      onUpdated: (user) => capturedByCallback = user,
      fileSizeReader: fileSizeReader ?? (_) async => 1024,
    );
  }

  setUp(() {
    useCase = MockUploadAvatarUseCase();
    picker = MockAvatarImagePicker();
    capturedByCallback = null;
  });

  group('pickAndUploadFromCamera', () {
    test('a cancelled pick (null path) is a no-op', () async {
      when(() => picker.pickFromCamera()).thenAnswer((_) async => null);
      final provider = buildProvider();

      final result = await provider.pickAndUploadFromCamera();

      expect(result, isFalse);
      expect(provider.isUploading, isFalse);
      expect(provider.errorMessage, isNull);
      verifyNever(() => useCase(any(), filePath: any(named: 'filePath')));
    });

    test('rejects a file over 5MB without calling the use case', () async {
      when(() => picker.pickFromCamera())
          .thenAnswer((_) async => '/tmp/photo.jpg');
      final provider =
          buildProvider(fileSizeReader: (_) async => 6 * 1024 * 1024);

      final result = await provider.pickAndUploadFromCamera();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(provider.isUploading, isFalse);
      verifyNever(() => useCase(any(), filePath: any(named: 'filePath')));
    });

    test('rejects an unsupported extension without calling the use case',
        () async {
      when(() => picker.pickFromCamera())
          .thenAnswer((_) async => '/tmp/document.pdf');
      final provider = buildProvider();

      final result = await provider.pickAndUploadFromCamera();

      expect(result, isFalse);
      expect(provider.errorMessage, isNotNull);
      verifyNever(() => useCase(any(), filePath: any(named: 'filePath')));
    });

    test('on success, calls onUpdated and clears error/uploading state',
        () async {
      when(() => picker.pickFromCamera())
          .thenAnswer((_) async => '/tmp/photo.jpg');
      when(() => useCase('u1', filePath: '/tmp/photo.jpg'))
          .thenAnswer((_) async => const Right(_updatedUser));
      final provider = buildProvider();

      final result = await provider.pickAndUploadFromCamera();

      expect(result, isTrue);
      expect(provider.errorMessage, isNull);
      expect(provider.isUploading, isFalse);
      expect(capturedByCallback, _updatedUser);
    });

    test(
        'on failure, never calls onUpdated (current avatar is kept) and '
        'exposes the backend message', () async {
      when(() => picker.pickFromCamera())
          .thenAnswer((_) async => '/tmp/photo.jpg');
      when(() => useCase('u1', filePath: '/tmp/photo.jpg')).thenAnswer(
        (_) async => const Left(ServerFailure('Upload failed')),
      );
      final provider = buildProvider();

      final result = await provider.pickAndUploadFromCamera();

      expect(result, isFalse);
      expect(provider.errorMessage, 'Upload failed');
      expect(provider.isUploading, isFalse);
      expect(capturedByCallback, isNull);
    });

    test('sets isUploading to true only while the use case is in flight',
        () async {
      when(() => picker.pickFromCamera())
          .thenAnswer((_) async => '/tmp/photo.jpg');
      final completer = Completer<Either<Failure, UserEntity>>();
      when(() => useCase('u1', filePath: '/tmp/photo.jpg'))
          .thenAnswer((_) => completer.future);
      final provider = buildProvider();

      final future = provider.pickAndUploadFromCamera();
      await Future<void>.delayed(Duration.zero);
      expect(provider.isUploading, isTrue);

      completer.complete(const Right(_updatedUser));
      await future;
      expect(provider.isUploading, isFalse);
    });
  });

  group('pickAndUploadFromGallery', () {
    test('delegates to the gallery picker, not the camera', () async {
      when(() => picker.pickFromGallery()).thenAnswer((_) async => null);
      final provider = buildProvider();

      final result = await provider.pickAndUploadFromGallery();

      expect(result, isFalse);
      verify(() => picker.pickFromGallery()).called(1);
      verifyNever(() => picker.pickFromCamera());
    });
  });
}
