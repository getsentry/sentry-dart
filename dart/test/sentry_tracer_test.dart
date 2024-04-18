import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_sentry_client.dart';

void main() {
  group('$SentryTracer', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
    });

    test('tracer sets name', () {
      final sut = fixture.getSut();

      expect(sut.name, 'name');
    });

    test('tracer sets unsampled', () {
      final sut = fixture.getSut(sampled: false);

      expect(sut.samplingDecision?.sampled, isFalse);
    });

    test('tracer sets sampled', () {
      final sut = fixture.getSut(sampled: true);

      expect(sut.samplingDecision?.sampled, isTrue);
    });

    test('tracer origin from root span', () {
      final sut = fixture.getSut();

      expect(sut.origin, 'manual');
    });

    test('tracer finishes with status', () async {
      final sut = fixture.getSut();

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;
      final trace = tr.transaction.contexts.trace;

      expect(trace?.status.toString(), 'aborted');
    });

    test('tracer passes the trace context on finish', () async {
      final sut = fixture.getSut();

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;

      expect(tr.traceContext, isNotNull);
    });

    test('tracer finishes with end timestamp', () async {
      final sut = fixture.getSut();
      final endTimestamp = getUtcDateTime();

      await sut.finish(endTimestamp: endTimestamp);

      expect(sut.endTimestamp, endTimestamp);
    });

    test('tracer does not finish unfinished spans', () async {
      final sut = fixture.getSut();
      sut.startChild('child');

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;
      final child = tr.transaction.spans.first;

      expect(child.status, isNull);
      expect(child.endTimestamp, isNull);
    });

    test('tracer sets data to extra', () async {
      final sut = fixture.getSut();

      sut.setData('test', 'test');

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;

      // ignore: deprecated_member_use_from_same_package
      expect(tr.transaction.extra?['test'], 'test');
    });

    test('tracer removes data to extra', () async {
      final sut = fixture.getSut();

      sut.setData('test', 'test');
      sut.removeData('test');

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;

      // ignore: deprecated_member_use_from_same_package
      expect(tr.transaction.extra?['test'], isNull);
    });

    test('tracer sets non-string data to extra', () async {
      final sut = fixture.getSut();

      sut.setData('test', {'key': 'value'});

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;

      // ignore: deprecated_member_use_from_same_package
      expect(tr.transaction.extra?['test'], {'key': 'value'});
    });

    test('tracer starts child', () async {
      final sut = fixture.getSut();

      final child = sut.startChild('operation', description: 'desc');
      await child.finish();

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;
      final childSpan = tr.transaction.spans.first;

      expect(childSpan.context.description, 'desc');
      expect(childSpan.context.operation, 'operation');
    });

    test('tracer starts child with parentSpanId', () async {
      final sut = fixture.getSut();
      final parentId = SpanId.newId();
      final child = sut.startChildWithParentSpanId(
        parentId,
        'op',
        description: 'desc',
      );
      await child.finish();

      await sut.finish(status: SpanStatus.aborted());

      final tr = fixture.hub.captureTransactionCalls.first;
      final childSpan = tr.transaction.spans.first;

      expect(childSpan.context.description, 'desc');
      expect(childSpan.context.operation, 'op');
      expect(childSpan.context.parentSpanId.toString(), parentId.toString());
    });

    test('tracer passes sampled decision to child', () async {
      final sut = fixture.getSut();
      final parentId = SpanId.newId();
      final child = sut.startChildWithParentSpanId(
        parentId,
        'op',
        description: 'desc',
      );
      await child.finish();

      await sut.finish(status: SpanStatus.aborted());

      expect(child.samplingDecision?.sampled, isTrue);
    });

    test('tracer passes unsampled decision to child', () async {
      final sut = fixture.getSut(sampled: false);
      final parentId = SpanId.newId();
      final child = sut.startChildWithParentSpanId(
        parentId,
        'op',
        description: 'desc',
      );
      await child.finish();

      await sut.finish(status: SpanStatus.aborted());

      expect(child.samplingDecision?.sampled, isFalse);
    });

    test('toSentryTrace returns trace header', () {
      final sut = fixture.getSut();

      expect(sut.toSentryTrace().value,
          '${sut.context.traceId}-${sut.context.spanId}-1');
    });

    test('finish isnt allowed to be called twice', () async {
      final sut = fixture.getSut();

      await sut.finish(status: SpanStatus.ok());
      await sut.finish(status: SpanStatus.cancelled());

      expect(sut.status, SpanStatus.ok());
    });

    test('removeData isnt allowed to be called after finishing', () async {
      final sut = fixture.getSut();

      sut.setData('key', 'value');
      await sut.finish(status: SpanStatus.ok());
      sut.removeData('key');

      expect(sut.data['key'], 'value');
    });

    test('removeTag isnt allowed to be called after finishing', () async {
      final sut = fixture.getSut();

      sut.setTag('key', 'value');
      await sut.finish(status: SpanStatus.ok());
      sut.removeTag('key');

      expect(sut.tags['key'], 'value');
    });

    test('setData isnt allowed to be called after finishing', () async {
      final sut = fixture.getSut();

      sut.setData('key', 'value');
      await sut.finish(status: SpanStatus.ok());
      sut.setData('key', 'value2');

      expect(sut.data['key'], 'value');
    });

    test('setTag isnt allowed to be called after finishing', () async {
      final sut = fixture.getSut();

      sut.setTag('key', 'value');
      await sut.finish(status: SpanStatus.ok());
      sut.setTag('key', 'value2');

      expect(sut.tags['key'], 'value');
    });

    test('startChild isnt allowed to be called after finishing', () async {
      final sut = fixture.getSut();

      await sut.finish(status: SpanStatus.ok());
      final span = sut.startChild('op');

      expect(NoOpSentrySpan(), span);
    });

    test('tracer finishes after auto finish duration', () async {
      final sut = fixture.getSut(autoFinishAfter: Duration(milliseconds: 200));

      expect(sut.finished, false);
      await Future.delayed(Duration(milliseconds: 210));
      expect(sut.status, SpanStatus.ok());
      expect(sut.finished, true);
    });

    test('tracer reschedule finish timer', () async {
      final sut = fixture.getSut(autoFinishAfter: Duration(milliseconds: 200));

      final currentTimer = sut.autoFinishAfterTimer!;

      sut.scheduleFinish();

      final newTimer = sut.autoFinishAfterTimer!;

      expect(currentTimer, isNot(equals(newTimer)));
    });

    test('tracer do not reschedule if finished', () async {
      final sut = fixture.getSut(autoFinishAfter: Duration(milliseconds: 200));

      final currentTimer = sut.autoFinishAfterTimer!;

      await sut.finish();

      sut.scheduleFinish();

      final newTimer = sut.autoFinishAfterTimer!;

      expect(currentTimer, newTimer);
    });

    test('tracer finish needs child to finish', () async {
      final sut = fixture.getSut(waitForChildren: true);

      final child = sut.startChild('operation', description: 'description');

      await sut.finish();
      expect(sut.finished, false);

      await child.finish();
      expect(sut.finished, true);
    });

    test('tracer finish needs all children to finish', () async {
      final sut = fixture.getSut(waitForChildren: true);

      final childA = sut.startChild('operation-a', description: 'description');
      final childB = sut.startChild('operation-b', description: 'description');

      await sut.finish();
      expect(sut.finished, false);

      await childA.finish();
      expect(sut.finished, false);

      await childB.finish();
      expect(sut.finished, true);
    });

    test(
        'tracer without finish will not be finished when children are finished',
        () async {
      final sut = fixture.getSut(waitForChildren: true);

      final childA = sut.startChild('operation-a', description: 'description');
      final childB = sut.startChild('operation-b', description: 'description');

      await childA.finish();
      expect(sut.finished, false);

      await childB.finish();
      expect(sut.finished, false);

      await sut.finish();
      expect(sut.finished, true);
    });

    test('end trimmed to last child', () async {
      final sut = fixture.getSut(trimEnd: true);
      final endTimestamp = getUtcDateTime().add(Duration(minutes: 1));
      final olderEndTimeStamp = endTimestamp.add(Duration(seconds: 1));
      final oldestEndTimeStamp = olderEndTimeStamp.add(Duration(seconds: 1));

      final childA = sut.startChild('operation-a', description: 'description');
      final childB = sut.startChild('operation-b', description: 'description');

      await childA.finish(endTimestamp: endTimestamp);
      await childB.finish(endTimestamp: olderEndTimeStamp);
      await sut.finish(endTimestamp: oldestEndTimeStamp);

      expect(sut.endTimestamp, childB.endTimestamp);
    });

    test('end trimmed to child', () async {
      final sut = fixture.getSut(trimEnd: true);
      final endTimestamp = getUtcDateTime().add(Duration(minutes: 1));
      final olderEndTimeStamp = endTimestamp.add(Duration(seconds: 1));

      final childA = sut.startChild('operation-a', description: 'description');

      await childA.finish(endTimestamp: endTimestamp);
      await sut.finish(endTimestamp: olderEndTimeStamp);

      expect(sut.endTimestamp, childA.endTimestamp);
    });

    test('end not trimmed when no child', () async {
      final sut = fixture.getSut(trimEnd: true);
      final endTimestamp = getUtcDateTime();

      await sut.finish(endTimestamp: endTimestamp);

      expect(sut.endTimestamp, endTimestamp);
    });

    test('end trimmed to latest child end timestamp', () async {
      final sut = fixture.getSut(trimEnd: true);
      final rootEndInitial = getUtcDateTime();

      final childAEnd = rootEndInitial;
      final childBEnd = rootEndInitial.add(Duration(seconds: 1));
      final childCEnd = rootEndInitial;

      final childA = sut.startChild('operation-a', description: 'description');
      final childB = sut.startChild('operation-b', description: 'description');
      final childC = sut.startChild('operation-c', description: 'description');

      await childA.finish(endTimestamp: childAEnd);
      await childB.finish(endTimestamp: childBEnd);
      await childC.finish(endTimestamp: childCEnd);

      await sut.finish(endTimestamp: rootEndInitial);

      expect(sut.endTimestamp, equals(childB.endTimestamp),
          reason:
              'The root end timestamp should be updated to match the latest child end timestamp.');
    });

    test('does not add more spans than configured in options', () async {
      fixture.hub.options.maxSpans = 2;
      final sut = fixture.getSut();

      sut.startChild('child1');
      sut.startChild('child2');
      sut.startChild('child3');

      expect(sut.children.length, 2);
    });

    test('when span limit is reached, startChild returns NoOpSpan', () async {
      fixture.hub.options.maxSpans = 2;
      final sut = fixture.getSut();

      sut.startChild('child1');
      sut.startChild('child2');

      expect(sut.startChild('child3'), isA<NoOpSentrySpan>());
    });

    test('do not capture idle transaction without children', () async {
      final sut = fixture.getSut(autoFinishAfter: Duration(milliseconds: 200));

      await sut.finish();

      expect(fixture.hub.captureTransactionCalls.isEmpty, true);
    });

    test('tracer sets measurement', () async {
      final sut = fixture.getSut();

      sut.setMeasurement('key', 1.0);

      expect(sut.measurements['key']!.value, 1.0);

      await sut.finish();
    });

    test('tracer sets custom measurement unit', () async {
      final sut = fixture.getSut();

      sut.setMeasurement('key', 1.0, unit: DurationSentryMeasurementUnit.hour);

      expect(sut.measurements['key']!.value, 1.0);
      expect(sut.measurements['key']?.unit, DurationSentryMeasurementUnit.hour);

      await sut.finish();
    });

    test('tracer does not allow setting measurement if finished', () async {
      final sut = fixture.getSut();

      await sut.finish();

      sut.setMeasurement('key', 1.0);

      expect(sut.measurements.isEmpty, true);
    });

    test('localMetricsAggregator is set when option is enabled', () async {
      fixture.hub.options.enableMetrics = true;
      fixture.hub.options.enableSpanLocalMetricAggregation = true;
      final sut = fixture.getSut();
      expect(fixture.hub.options.enableSpanLocalMetricAggregation, true);
      expect(sut.localMetricsAggregator, isNotNull);
    });

    test('localMetricsAggregator is null when option is disabled', () async {
      fixture.hub.options.enableMetrics = false;
      final sut = fixture.getSut();
      expect(fixture.hub.options.enableSpanLocalMetricAggregation, false);
      expect(sut.localMetricsAggregator, null);
    });
  });

  group('$SentryBaggageHeader', () {
    late Fixture _fixture;
    late Hub _hub;

    setUp(() async {
      _fixture = Fixture();
      _hub = Hub(_fixture.options);
      _hub.configureScope((scope) => scope.setUser(_fixture.user));

      _hub.bindClient(_fixture.client);
    });

    SentryTracer getSut({SentryTracesSamplingDecision? samplingDecision}) {
      final decision = samplingDecision ??
          SentryTracesSamplingDecision(
            true,
            sampleRate: 1.0,
          );
      final _context = SentryTransactionContext(
        'name',
        'op',
        transactionNameSource: SentryTransactionNameSource.custom,
        samplingDecision: decision,
      );

      return SentryTracer(_context, _hub);
    }

    test('returns baggage header', () {
      final sut = getSut();
      final baggage = sut.toBaggageHeader();

      expect(baggage!.name, 'baggage');

      final newBaggage = SentryBaggage.fromHeader(baggage.value);
      expect(newBaggage.get('sentry-trace_id'), sut.context.traceId.toString());
      expect(newBaggage.get('sentry-public_key'), 'abc');
      expect(newBaggage.get('sentry-release'), 'release');
      expect(newBaggage.get('sentry-environment'), 'environment');
      expect(newBaggage.get('sentry-user_segment'), 'segment');
      expect(newBaggage.get('sentry-transaction'), 'name');
      expect(newBaggage.get('sentry-sample_rate'), '1');
      expect(newBaggage.get('sentry-sampled'), 'true');
    });

    test('skip transaction name if low cardinality', () {
      final sut = getSut();
      sut.transactionNameSource = SentryTransactionNameSource.url;
      final baggage = sut.toBaggageHeader();

      final newBaggage = SentryBaggage.fromHeader(baggage!.value);
      expect(newBaggage.get('sentry-transaction'), isNull);
    });

    test('sets transactionNameSource to source if not given', () {
      final _context = SentryTransactionContext(
        'name',
        'op',
      );

      final tracer = SentryTracer(_context, _hub);
      expect(tracer.transactionNameSource, SentryTransactionNameSource.custom);
    });

    test('formats the sample rate correctly', () {
      final sut = getSut(
          samplingDecision: SentryTracesSamplingDecision(
        true,
        sampleRate: 0.00000021,
      ));
      final baggage = sut.toBaggageHeader();

      final newBaggage = SentryBaggage.fromHeader(baggage!.value);
      expect(newBaggage.get('sentry-sample_rate'), '0.00000021');
    });
  });

  group('$SentryTraceContextHeader', () {
    late Fixture _fixture;
    late Hub _hub;

    setUp(() async {
      _fixture = Fixture();
      _hub = Hub(_fixture.options);
      _hub.configureScope((scope) => scope.setUser(_fixture.user));

      _hub.bindClient(_fixture.client);
    });

    SentryTracer getSut({SentryTracesSamplingDecision? samplingDecision}) {
      final decision = samplingDecision ??
          SentryTracesSamplingDecision(
            true,
            sampleRate: 1.0,
          );
      final _context = SentryTransactionContext(
        'name',
        'op',
        transactionNameSource: SentryTransactionNameSource.custom,
        samplingDecision: decision,
      );

      return SentryTracer(_context, _hub);
    }

    test('returns trace context header', () {
      final sut = getSut();
      final context = sut.traceContext();

      expect(context!.traceId, sut.context.traceId);
      expect(context.publicKey, 'abc');
      expect(context.release, 'release');
      expect(context.environment, 'environment');
      expect(context.userSegment, 'segment');
      expect(context.transaction, 'name');
      expect(context.sampleRate, '1');
      expect(context.sampled, 'true');
    });
  });
}

class Fixture {
  final options = SentryOptions(dsn: fakeDsn)
    ..release = 'release'
    ..environment = 'environment';

  final client = MockSentryClient();

  final user = SentryUser(
    id: 'id',
    segment: 'segment',
  );

  final hub = MockHub();

  SentryTracer getSut({
    bool? sampled = true,
    bool waitForChildren = false,
    bool trimEnd = false,
    Duration? autoFinishAfter,
  }) {
    final context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(sampled!),
      origin: 'manual',
    );
    return SentryTracer(
      context,
      hub,
      waitForChildren: waitForChildren,
      autoFinishAfter: autoFinishAfter,
      trimEnd: trimEnd,
    );
  }
}
