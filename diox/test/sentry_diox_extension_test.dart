import 'package:diox/diox.dart';
import 'package:sentry_diox/sentry_dio.dart';
import 'package:sentry_diox/src/sentry_diox_client_adapter.dart';
import 'package:sentry_diox/src/sentry_diox_extension.dart';
import 'package:sentry_diox/src/sentry_transformer.dart';
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

    test('addSentry adds $SentryDioxClientAdapter', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(dio.httpClientAdapter, isA<SentryDioxClientAdapter>());
    });

    test('addSentry adds $DioxEventProcessor', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.eventProcessors
            .whereType<DioxEventProcessor>()
            .length,
        1,
      );
    });

    test('addSentry only adds one $DioxEventProcessor', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);
      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.eventProcessors
            .whereType<DioxEventProcessor>()
            .length,
        1,
      );
    });

    test('addSentry adds integration to sdk', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.sdk.integrations.contains('sentry_diox'),
        true,
      );
    });

    test('addSentry only adds one integration to sdk', () {
      final dio = fixture.getSut();

      dio.addSentry(hub: fixture.hub);
      dio.addSentry(hub: fixture.hub);

      expect(
        fixture.hub.options.sdk.integrations
            .where((it) => it == 'sentry_diox')
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
