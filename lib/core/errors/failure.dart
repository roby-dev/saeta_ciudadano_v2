import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error']);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Invalid credentials']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred']);
}
