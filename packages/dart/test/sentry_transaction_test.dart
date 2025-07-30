import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'test_utils.dart';

void main() {
  final fixture = Fixture();

  SentryTracer _createTracer({
    bool? sampled = true,
    Hub? hub,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(sampled!),
      transactionNameSource: SentryTransactionNameSource.component,
    );
    return SentryTracer(context, hub ?? MockHub());
  }

  test('toJson serializes', () async {
    final tracer = _createTracer(hub: fixture.hub);

    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);
    final map = sut.toJson();

    expect(map['type'], 'transaction');
    expect(map['start_timestamp'], isNotNull);
    expect(map['spans'], isNotNull);
    expect(map['transaction_info']['source'], 'component');
  });

  test('returns finished if it is', () async {
    final tracer = _createTracer();
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.finished, true);
  });

  test('returns sampled if theres context', () async {
    final tracer = _createTracer(sampled: true);
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.sampled, true);
  });

  test('returns contexts.trace.data if data is set', () async {
    final tracer = _createTracer(sampled: true);
    tracer.setData('key', 'value');
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.contexts.trace!.data, {'key': 'value'});
  });

  test('returns null contexts.trace.data if data is not set', () async {
    final tracer = _createTracer(sampled: true);
    final child = tracer.startChild('child');
    await child.finish();
    await tracer.finish();

    final sut = fixture.getSut(tracer);

    expect(sut.contexts.trace!.data, isNull);
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
  final SentryOptions options = defaultTestOptions();
  late final Hub hub = Hub(options);

  SentryTransaction getSut(SentryTracer tracer) {
    return SentryTransaction(tracer);
  }
}
