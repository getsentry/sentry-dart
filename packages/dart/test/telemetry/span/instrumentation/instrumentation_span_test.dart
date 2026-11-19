import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/instrumentation/span_links.dart';
import 'package:test/test.dart';

import '../../../test_utils.dart';

void main() {
  group('$InstrumentationSpan', () {
    group('$StreamingInstrumentationSpan', () {
      late Fixture fixture;

      setUp(() {
        fixture = Fixture();
      });

      group('setData', () {
        test('with List<String> sets an array attribute', () {
          final sut = fixture.getSut();
          sut.setData('tags', ['a', 'b']);
          final attr = fixture.recordingSpan.attributes['tags'];
          expect(attr?.toJson(), {
            'value': ['a', 'b'],
            'type': 'array',
          });
        });

        test('with List<int> sets an array attribute', () {
          final sut = fixture.getSut();
          sut.setData('codes', [1, 2]);
          final attr = fixture.recordingSpan.attributes['codes'];
          expect(attr?.toJson(), {
            'value': [1, 2],
            'type': 'array',
          });
        });

        test('with List<double> sets an array attribute', () {
          final sut = fixture.getSut();
          sut.setData('scores', [1.0, 2.0]);
          final attr = fixture.recordingSpan.attributes['scores'];
          expect(attr?.toJson(), {
            'value': [1.0, 2.0],
            'type': 'array',
          });
        });

        test('with List<bool> sets an array attribute', () {
          final sut = fixture.getSut();
          sut.setData('flags', [true, false]);
          final attr = fixture.recordingSpan.attributes['flags'];
          expect(attr?.toJson(), {
            'value': [true, false],
            'type': 'array',
          });
        });

        test('with mixed List ignores the value', () {
          final sut = fixture.getSut();
          sut.setData('mixed', <Object>[1, 'a', true]);
          expect(
            fixture.recordingSpan.attributes.containsKey('mixed'),
            isFalse,
          );
        });

        test('with List containing null ignores the value', () {
          final sut = fixture.getSut();
          sut.setData('nullable', <String?>['a', null]);
          expect(
            fixture.recordingSpan.attributes.containsKey('nullable'),
            isFalse,
          );
        });
      });

      test('setting throwable links it to the span', () {
        final sut = fixture.getSut();
        final throwable = Exception('boom');

        sut.throwable = throwable;

        expect(spanLinks.spanFor(throwable), same(fixture.recordingSpan));
      });

      test('linkTo links the key to the span', () {
        final sut = fixture.getSut();
        final request = Object();

        sut.linkTo(request);

        expect(spanLinks.spanFor(request), same(fixture.recordingSpan));
      });

      test('linkTo with replace moves the key to the span', () {
        final request = Object();
        fixture.getSut().linkTo(request);
        final retry = StreamingInstrumentationSpan(
          fixture.createRecordingSpan(),
        );

        retry.linkTo(request, replace: true);

        expect(spanLinks.spanFor(request), same(retry.spanReference));
      });
    });

    group('$LegacyInstrumentationSpan', () {
      test('linkTo does not link the key', () {
        final sut = LegacyInstrumentationSpan(NoOpSentrySpan());
        final request = Object();

        sut.linkTo(request);

        expect(spanLinks.spanFor(request), isNull);
      });
    });
  });
}

class Fixture {
  late final RecordingSentrySpanV2 recordingSpan = createRecordingSpan();

  RecordingSentrySpanV2 createRecordingSpan() => RecordingSentrySpanV2.root(
    name: 'test-span',
    traceId: SentryId.newId(),
    onSpanEnd: (_) async {},
    clock: defaultTestOptions().clock,
    dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
    samplingDecision: SentryTracesSamplingDecision(true),
  );

  StreamingInstrumentationSpan getSut() {
    return StreamingInstrumentationSpan(recordingSpan);
  }
}
