import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_dio/src/sentry_dio_client_adapter.dart';
import 'package:sentry_dio/src/sentry_dio_extension.dart';
import 'package:sentry_dio/src/sentry_transformer.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  group('SentryDioExtension', () {
    test('addSentry adds $SentryTransformer', () {
      final dio = Dio();
      final hub = MockHub();

      dio.addSentry(hub: hub);

      expect(dio.transformer, isA<SentryTransformer>());
    });

    test('addSentry adds $SentryDioClientAdapter', () {
      final dio = Dio();
      final hub = MockHub();

      dio.addSentry(hub: hub);

      expect(dio.httpClientAdapter, isA<SentryDioClientAdapter>());
    });

    test('addSentry adds $DioEventProcessor', () {
      final dio = Dio();
      final hub = MockHub();

      dio.addSentry(hub: hub);

      expect(
        hub.options.eventProcessors.whereType<DioEventProcessor>().length,
        1,
      );
    });

    test('addSentry only adds one $DioEventProcessor', () {
      final dio = Dio();
      final hub = MockHub();

      dio.addSentry(hub: hub);
      dio.addSentry(hub: hub);

      expect(
        hub.options.eventProcessors.whereType<DioEventProcessor>().length,
        1,
      );
    });
  });
}
