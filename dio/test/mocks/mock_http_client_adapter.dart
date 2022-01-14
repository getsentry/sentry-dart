import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef MockFetchMethod = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
  Future<dynamic>? cancelFuture,
);

class MockHttpClientAdapter extends HttpClientAdapter {
  MockHttpClientAdapter(this.mockFetchMethod);

  final MockFetchMethod mockFetchMethod;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    return mockFetchMethod(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
