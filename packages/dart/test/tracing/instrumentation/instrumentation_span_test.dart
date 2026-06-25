import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
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
          'type': 'array'
        });
      });

      test('with List<int> sets an array attribute', () {
        final sut = fixture.getSut();
        sut.setData('codes', [1, 2]);
        final attr = fixture.recordingSpan.attributes['codes'];
        expect(attr?.toJson(), {
          'value': [1, 2],
          'type': 'array'
        });
      });

      test('with List<double> sets an array attribute', () {
        final sut = fixture.getSut();
        sut.setData('scores', [1.0, 2.0]);
        final attr = fixture.recordingSpan.attributes['scores'];
        expect(attr?.toJson(), {
          'value': [1.0, 2.0],
          'type': 'array'
        });
      });

      test('with List<bool> sets an array attribute', () {
        final sut = fixture.getSut();
        sut.setData('flags', [true, false]);
        final attr = fixture.recordingSpan.attributes['flags'];
        expect(attr?.toJson(), {
          'value': [true, false],
          'type': 'array'
        });
      });

      test('with mixed List ignores the value', () {
        final sut = fixture.getSut();
        sut.setData('mixed', <Object>[1, 'a', true]);
        expect(fixture.recordingSpan.attributes.containsKey('mixed'), isFalse);
      });

      test('with List containing null ignores the value', () {
        final sut = fixture.getSut();
        sut.setData('nullable', <String?>['a', null]);
        expect(
            fixture.recordingSpan.attributes.containsKey('nullable'), isFalse);
      });
    });
  });
}

class Fixture {
  final RecordingSentrySpanV2 recordingSpan;

  Fixture()
      : recordingSpan = RecordingSentrySpanV2.root(
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
