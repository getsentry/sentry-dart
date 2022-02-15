import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'no_such_method_provider.dart';

typedef MockFetchMethod = Future<ResponseBody> Function(
  RequestOptions options,
  Stream<Uint8List>? requestStream,
  Future<dynamic>? cancelFuture,
);

class MockHttpClientAdapter extends HttpClientAdapter
    with NoSuchMethodProvider {
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
