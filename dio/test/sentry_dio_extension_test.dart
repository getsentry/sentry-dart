import 'package:dio/dio.dart';
import 'package:sentry_dio/src/sentry_client_adapter.dart';
import 'package:sentry_dio/src/sentry_dio_extension.dart';
import 'package:sentry_dio/src/sentry_transformer.dart';
import 'package:test/test.dart';

// todo: figure out a way to test if parameter are passed through correctly

void main() {
  group('SentryDioExtension', () {
    test('addSentry add client and transformer', () {
      final dio = Dio();
      dio.addSentry();
      expect(dio.httpClientAdapter, isA<SentryHttpClientAdapter>());
      expect(dio.transformer, isA<SentryTransformer>());
    });
  });
}
