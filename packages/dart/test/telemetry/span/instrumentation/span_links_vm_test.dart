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
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('ignores FFI objects when linking a span', () {
      final sut = fixture.getSut();
      final span = fixture.createRecordingSpan();

      for (final key in [
        nullptr,
        Struct.create<_Struct>(),
        Union.create<_Union>(),
      ]) {
        sut.link(key, span);
        expect(sut.spanFor(key), isNull);
      }
    });

    test('allows the hub to capture a pointer throwable', () async {
      await fixture.hub.captureException(nullptr);

      expect(
        fixture.client.captureEventCalls.single.event.throwable,
        same(nullptr),
      );
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

class Fixture {
  final client = MockSentryClient();
  late final hub = Hub(defaultTestOptions())..bindClient(client);

  SpanLinks getSut() => SpanLinks();

  RecordingSentrySpanV2 createRecordingSpan() {
    hub.options.tracesSampleRate = 1;
    return hub.startInactiveSpan('segment') as RecordingSentrySpanV2;
  }
}
