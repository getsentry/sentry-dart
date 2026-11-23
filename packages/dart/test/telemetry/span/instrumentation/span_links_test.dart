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

    test('keeps the inner span when an enclosing span links the key', () {
      final sut = fixture.getSut();
      final key = Exception('boom');
      final outer = fixture.createSpan('outer');
      final middle = fixture.createChild(outer, 'middle');
      final inner = fixture.createChild(middle, 'inner');

      sut.link(key, inner);
      sut.link(key, middle);
      sut.link(key, outer);

      expect(sut.spanFor(key), same(inner));
    });

    test('relinks the key to a span in another trace', () {
      final sut = fixture.getSut();
      final key = Exception('boom');
      final first = fixture.createSpan('first');
      final second = fixture.createSpan('second');

      sut.link(key, first);
      sut.link(key, second);

      expect(sut.spanFor(key), same(second));
    });

    test('relinks the key to a sibling span', () {
      final sut = fixture.getSut();
      final key = Object();
      final parent = fixture.createSpan('parent');
      final first = fixture.createChild(parent, 'first');
      final retry = fixture.createChild(parent, 'retry');

      sut.link(key, first);
      sut.link(key, retry);

      expect(sut.spanFor(key), same(retry));
    });

    test('relinks the key to a span nested in the linked span', () {
      final sut = fixture.getSut();
      final key = Object();
      final outer = fixture.createSpan('outer');
      final inner = fixture.createChild(outer, 'inner');

      sut.link(key, outer);
      sut.link(key, inner);

      expect(sut.spanFor(key), same(inner));
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

  RecordingSentrySpanV2 createChild(
    RecordingSentrySpanV2 parent,
    String name,
  ) => RecordingSentrySpanV2.child(
    parent: parent,
    name: name,
    onSpanEnd: (_) async {},
    clock: defaultTestOptions().clock,
    dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
  );

  SpanLinks getSut() => SpanLinks();
}
