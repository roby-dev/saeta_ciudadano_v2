import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../../domain/repositories/emergency_contacts_repository.dart';
import '../datasources/emergency_contacts_remote_datasource.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactsRepositoryImpl implements EmergencyContactsRepository {
  const EmergencyContactsRepositoryImpl(this._dataSource);

  final EmergencyContactsRemoteDataSource _dataSource;

  String _extractErrorMessage(dynamic data, String defaultMessage) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is List) {
        return msg.map((e) => e.toString()).join('\n');
      }
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    return defaultMessage;
  }

  @override
  Future<Either<Failure, List<EmergencyContactEntity>>> getContacts(
    String userId,
  ) async {
    try {
      final models = await _dataSource.getContacts(userId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Failed to load emergency contacts',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, List<EmergencyContactEntity>>> saveContacts(
    String userId,
    List<EmergencyContactEntity> contacts,
  ) async {
    try {
      final models = await _dataSource.saveContacts(
        userId,
        contacts.map((e) => EmergencyContactModel.fromEntity(e)).toList(),
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      final message = _extractErrorMessage(
        e.response?.data,
        e.response?.statusMessage ?? 'Failed to save emergency contacts',
      );
      return Left(ServerFailure(message));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
