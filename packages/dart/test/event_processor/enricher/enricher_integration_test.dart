// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/enricher/enricher_event_processor.dart';
import 'package:sentry/src/event_processor/enricher/enricher_integration.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('EnricherIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when calling', () {
      test('registers the enricher as an event processor', () {
        fixture.getSut().call(HubAdapter(), fixture.options);

        expect(
          fixture.options.eventProcessors.contains(fixture.enricher),
          isTrue,
        );
      });

      test('adds enricherIntegration to SDK integrations', () {
        fixture.getSut().call(HubAdapter(), fixture.options);

        expect(
            fixture.options.sdk.integrations, contains('enricherIntegration'));
      });
    });

    group('when enableLogs is true', () {
      setUp(() {
        fixture.options.enableLogs = true;
      });

      test('adds minimal device and os attributes to logs', () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final log = fixture.givenLog();

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessLog(log));

        expect(log.attributes['device.brand']?.value, 'enricher-brand');
        expect(log.attributes['device.model']?.value, 'enricher-model');
        expect(log.attributes['device.family']?.value, 'enricher-family');
        expect(log.attributes['os.name']?.value, 'enricher-os');
      });

      test('does not emit app attributes on logs', () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final log = fixture.givenLog();

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessLog(log));

        expect(log.attributes.containsKey('app.version'), isFalse);
      });

      test('does not override existing log attributes', () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final log = fixture.givenLog();
        log.attributes['device.brand'] = SentryAttribute.string('existing');

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessLog(log));

        expect(log.attributes['device.brand']?.value, 'existing');
      });
    });

    group('when enableLogs is false', () {
      setUp(() {
        fixture.options.enableLogs = false;
      });

      test('does not register a log callback', () {
        fixture.getSut().call(HubAdapter(), fixture.options);

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessLog],
          anyOf(isNull, isEmpty),
        );
      });
    });

    group('when enableMetrics is true', () {
      setUp(() {
        fixture.options.enableMetrics = true;
      });

      test('adds minimal device attributes to metrics', () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final metric = fixture.givenMetric();

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessMetric(metric));

        expect(metric.attributes['device.brand']?.value, 'enricher-brand');
        expect(metric.attributes['device.model']?.value, 'enricher-model');
        expect(metric.attributes['device.family']?.value, 'enricher-family');
      });
    });

    group('when enableMetrics is false', () {
      setUp(() {
        fixture.options.enableMetrics = false;
      });

      test('does not register a metric callback', () {
        fixture.getSut().call(HubAdapter(), fixture.options);

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessMetric],
          anyOf(isNull, isEmpty),
        );
      });
    });

    group('when traceLifecycle is stream', () {
      setUp(() {
        fixture.options.traceLifecycle = SentryTraceLifecycle.stream;
      });

      test('adds minimal device and os attributes to non-segment spans',
          () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final segmentSpan = fixture.createRecordingSpan();
        final childSpan = fixture.createRecordingSpan(parent: segmentSpan);

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(childSpan));

        final attributes = childSpan.attributes;
        expect(attributes['device.brand']?.value, 'enricher-brand');
        expect(attributes['device.model']?.value, 'enricher-model');
        expect(attributes['device.family']?.value, 'enricher-family');
        expect(attributes['os.name']?.value, 'enricher-os');
        expect(attributes.containsKey('app.version'), isFalse);
      });

      test('adds full contexts attributes to segment spans', () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final segmentSpan = fixture.createRecordingSpan();

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(segmentSpan));

        final attributes = segmentSpan.attributes;
        expect(attributes['device.brand']?.value, 'enricher-brand');
        expect(attributes['os.name']?.value, 'enricher-os');
        expect(attributes['app.version']?.value, 'enricher-app-version');
      });

      test('does not override existing span attributes', () async {
        fixture.getSut().call(HubAdapter(), fixture.options);
        final segmentSpan = fixture.createRecordingSpan();
        segmentSpan.setAttribute(
            'device.brand', SentryAttribute.string('existing'));

        await fixture.options.lifecycleRegistry
            .dispatchCallback(OnProcessSpan(segmentSpan));

        expect(segmentSpan.attributes['device.brand']?.value, 'existing');
      });
    });

    group('when traceLifecycle is static', () {
      setUp(() {
        fixture.options.traceLifecycle = SentryTraceLifecycle.static;
      });

      test('does not register a span callback', () {
        fixture.getSut().call(HubAdapter(), fixture.options);

        expect(
          fixture.options.lifecycleRegistry.lifecycleCallbacks[OnProcessSpan],
          anyOf(isNull, isEmpty),
        );
      });
    });

    group('when closing', () {
      test('removes all registered lifecycle callbacks', () {
        fixture.options
          ..enableLogs = true
          ..enableMetrics = true
          ..traceLifecycle = SentryTraceLifecycle.stream;
        final sut = fixture.getSut();
        sut.call(HubAdapter(), fixture.options);

        sut.close();

        final callbacks = fixture.options.lifecycleRegistry.lifecycleCallbacks;
        expect(callbacks[OnProcessLog], anyOf(isNull, isEmpty));
        expect(callbacks[OnProcessMetric], anyOf(isNull, isEmpty));
        expect(callbacks[OnProcessSpan], anyOf(isNull, isEmpty));
      });
    });
  });
}

class _FakeEnricherEventProcessor implements EnricherEventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) => event;

  @override
  Future<Contexts> buildContexts() async {
    return Contexts(
      device: SentryDevice(
        brand: 'enricher-brand',
        model: 'enricher-model',
        family: 'enricher-family',
      ),
      operatingSystem: SentryOperatingSystem(name: 'enricher-os'),
      app: SentryApp(version: 'enricher-app-version'),
    );
  }
}

class Fixture {
  final options = defaultTestOptions();
  final enricher = _FakeEnricherEventProcessor();

  SentryLog givenLog() {
    return SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );
  }

  SentryMetric givenMetric() {
    return SentryCounterMetric(
      timestamp: DateTime.now(),
      name: 'random',
      value: 1,
      traceId: SentryId.newId(),
    );
  }

  RecordingSentrySpanV2 createRecordingSpan({
    String name = 'test-span',
    RecordingSentrySpanV2? parent,
  }) {
    if (parent == null) {
      return RecordingSentrySpanV2.root(
        name: name,
        traceId: SentryId.newId(),
        onSpanEnd: (_) async {},
        clock: options.clock,
        dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
        samplingDecision: SentryTracesSamplingDecision(true),
      );
    }
    return RecordingSentrySpanV2.child(
      parent: parent,
      name: name,
      onSpanEnd: (_) async {},
      clock: options.clock,
      dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
    );
  }

  EnricherIntegration getSut() => EnricherIntegration(enricher);
}
