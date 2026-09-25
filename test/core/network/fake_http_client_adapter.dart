import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Hand-written [HttpClientAdapter] fake used to test Dio interceptors
/// without touching the network or any generated mocks.
///
/// Every request made through this adapter is recorded in [requests], and
/// answered by calling [handler] with the incoming [RequestOptions].
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  final FutureOr<FakeResponse> Function(RequestOptions options) handler;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(result.data),
      result.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A canned response returned by [FakeHttpClientAdapter.handler].
class FakeResponse {
  const FakeResponse(this.statusCode, this.data);

  final int statusCode;
  final Map<String, dynamic> data;
}
