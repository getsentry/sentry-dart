import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';

void main() {
  final fixture = Fixture();

  SentryTracer _createTracer({
    bool? sampled,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      tracesSamplingDecision: SentryTracesSamplingDecision(sampled!),
    );
    return SentryTracer(context, MockHub());
  }

  test('toJson serializes', () async {
    final tracer = _createTracer();
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);
    final map = sut.toJson();

    expect(map['type'], 'transaction');
    expect(map['start_timestamp'], isNotNull);
    expect(map['spans'], isNotNull);
  });

  test('returns finished if it is', () async {
    final tracer = _createTracer();
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.finished, true);
  });

  // test('returns false for finished if not', () {
  //   final tracer = _createTracer();
  //   final child = tracer.startChild('child');
  //   child.finish();

  //   final sut = fixture.getSut(tracer);

  //   expect(sut.finished, false);
  // });

  test('returns sampled if theres context', () async {
    final tracer = _createTracer(sampled: true);
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.sampled, true);
  });

  test('returns sampled false if not sampled', () async {
    final tracer = _createTracer(sampled: false);
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.sampled, false);
  });
}

class Fixture {
  SentryTransaction getSut(SentryTracer tracer) {
    return SentryTransaction(tracer);
  }
}
