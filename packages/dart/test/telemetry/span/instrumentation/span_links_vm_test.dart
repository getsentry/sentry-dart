@TestOn('vm')
library;

import 'dart:ffi';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/instrumentation/span_links.dart';
import 'package:test/test.dart';

import '../../../mocks/mock_sentry_client.dart';
import '../../../test_utils.dart';

void main() {
  group('$SpanLinks', () {
    test('ignores FFI objects when linking a span', () async {
      final hub = Hub(defaultTestOptions()..tracesSampleRate = 1);
      final links = SpanLinks();

      await hub.startSpan('segment', (span) async {
        for (final key in [
          nullptr,
          Struct.create<_Struct>(),
          Union.create<_Union>(),
        ]) {
          links.link(key, span);
          expect(links.spanFor(key), isNull);
        }
      });
    });

    test('allows the hub to capture a pointer throwable', () async {
      final client = MockSentryClient();
      final hub = Hub(defaultTestOptions())..bindClient(client);

      await hub.captureException(nullptr);

      expect(client.captureEventCalls.single.event.throwable, same(nullptr));
    });
  });
}

final class _Struct extends Struct {
  @Int8()
  external int value;
}

final class _Union extends Union {
  @Int8()
  external int value;
}
