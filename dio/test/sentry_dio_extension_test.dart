import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_dio/src/dio_error_extractor.dart';
import 'package:sentry_dio/src/dio_stacktrace_extractor.dart';
import 'package:sentry_dio/src/sentry_dio_client_adapter.dart';
import 'package:sentry_dio/src/sentry_dio_extension.dart';
import 'package:sentry_dio/src/sentry_transformer.dart';
import 'package:sentry_dio/src/version.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });
  group('SentryDioExtension', () {
    test('addSentry adds $SentryTransformer', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(dio.transformer, isA<SentryTransformer>());
    });

    test('addSentry adds $SentryDioClientAdapter', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(dio.httpClientAdapter, isA<SentryDioClientAdapter>());
    });

    test('addSentry adds $DioEventProcessor', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.eventProcessors
            .whereType<DioEventProcessor>()
            .length,
        1,
      );
    });

    test('addSentry only adds one $DioEventProcessor', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);
      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.eventProcessors
            .whereType<DioEventProcessor>()
            .length,
        1,
      );
    });

    test('addSentry adds $DioErrorExtractor', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.exceptionCauseExtractor(DioError),
        isNotNull,
      );
    });

    test('addSentry adds $DioStackTraceExtractor', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.exceptionStackTraceExtractor(DioError),
        isNotNull,
      );
    });

    test('addSentry adds integration to sdk', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.sdk.integrations.contains('sentry_dio'),
        true,
      );
    });

    test('addSentry only adds one integration to sdk', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);
      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.sdk.integrations
            .where((it) => it == 'sentry_dio')
            .length,
        1,
      );
    });

    test('addSentry adds package to sdk', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.sdk.packages
            .where((it) => it.name == packageName && it.version == sdkVersion)
            .length,
        1,
      );
    });
  });
}

class Fixture {
  final MockHub hub = MockHub();
  Dio getSut() {
    return Dio();
  }
}
