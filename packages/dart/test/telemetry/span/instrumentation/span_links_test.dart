import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/instrumentation/span_links.dart';
import 'package:test/test.dart';

import '../../../test_utils.dart';

void main() {
  group('$SpanLinks', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns the span linked to a key', () {
      final sut = fixture.getSut();
      final key = Exception('boom');

      sut.link(key, fixture.span);

      expect(sut.spanFor(key), same(fixture.span));
    });

    test('returns null for an unlinked key', () {
      final sut = fixture.getSut();

      expect(sut.spanFor(Exception('boom')), isNull);
    });

    test('keeps the first span linked to a key', () {
      final sut = fixture.getSut();
      final key = Exception('boom');
      final inner = fixture.createSpan('inner');
      final outer = fixture.createSpan('outer');

      sut.link(key, inner);
      sut.link(key, outer);

      expect(sut.spanFor(key), same(inner));
    });

    test('with replace overwrites the linked span', () {
      final sut = fixture.getSut();
      final key = Object();
      final first = fixture.createSpan('first');
      final retry = fixture.createSpan('retry');

      sut.link(key, first);
      sut.link(key, retry, replace: true);

      expect(sut.spanFor(key), same(retry));
    });

    test('unwraps a $ThrowableMechanism key', () {
      final sut = fixture.getSut();
      final throwable = Exception('boom');

      sut.link(throwable, fixture.span);

      final wrapped = ThrowableMechanism(Mechanism(type: 'test'), throwable);
      expect(sut.spanFor(wrapped), same(fixture.span));
    });

    test('ignores keys that cannot be held weakly', () {
      final sut = fixture.getSut();
      final keys = <Object?>['boom', 42, 4.2, true, (1, 2), null];

      for (final key in keys) {
        sut.link(key, fixture.span);
      }

      expect(keys.map(sut.spanFor), everyElement(isNull));
    });

    test('ignores a non-recording span', () {
      final sut = fixture.getSut();
      final key = Exception('boom');

      sut.link(key, NoOpSentrySpanV2.instance);

      expect(sut.spanFor(key), isNull);
    });
  });
}

class Fixture {
  late final RecordingSentrySpanV2 span = createSpan('span');

  RecordingSentrySpanV2 createSpan(String name) => RecordingSentrySpanV2.root(
    name: name,
    traceId: SentryId.newId(),
    onSpanEnd: (_) async {},
    clock: defaultTestOptions().clock,
    dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
    samplingDecision: SentryTracesSamplingDecision(true),
  );

  SpanLinks getSut() => SpanLinks();
}
