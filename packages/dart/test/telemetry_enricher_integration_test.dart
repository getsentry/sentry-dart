@TestOn('vm')
library;

import 'package:sentry/src/constants.dart';
import 'package:sentry/src/telemetry/sentry_trace_lifecycle.dart';
import 'package:sentry/src/telemetry/telemetry_enricher_integration.dart';
import 'package:test/test.dart';
import 'package:sentry/src/hub.dart';
import 'package:sentry/src/protocol/sentry_log.dart';
import 'package:sentry/src/protocol/sentry_attribute.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:sentry/src/protocol/sentry_log_level.dart';
import 'package:sentry/src/protocol/sentry_user.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:sentry/src/sentry_trace_context_header.dart';
import 'package:sentry/src/sentry_traces_sampling_decision.dart';
import 'package:sentry/src/utils/os_utils.dart';
import 'test_utils.dart';

void main() {
  group('TelemetryEnricherIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when tracing is enabled in streaming mode', () {
      setUp(() {
        fixture.options.tracesSampleRate = 1.0;
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        fixture.callIntegration();
      });

      test('adds span enricher to sdk.integrations', () {
        expect(
          fixture.options.sdk.integrations.contains(
              TelemetryEnricherIntegration.spanEnricherIntegrationName),
          isTrue,
        );
      });

      test('adds common attributes to span', () async {
        fixture.options.environment = 'test';
        fixture.options.release = '1.0.0';
        fixture.hub.configureScope((scope) {
          scope.setUser(SentryUser(id: 'user-id', email: 'test@example.com'));
          scope.setAttributes(
              {'custom.scope': SentryAttribute.string('scope-value')});
        });

        final span = fixture.createSpan();
        await fixture.hub.captureSpan(span);

        final os = getSentryOperatingSystem();

        expect(
            span.attributes[SemanticAttributesConstants.sentrySdkName]?.value,
            fixture.options.sdk.name);
        expect(
            span.attributes[SemanticAttributesConstants.sentrySdkVersion]
                ?.value,
            fixture.options.sdk.version);
        expect(
            span.attributes[SemanticAttributesConstants.sentryEnvironment]
                ?.value,
            'test');
        expect(
            span.attributes[SemanticAttributesConstants.sentryRelease]?.value,
            '1.0.0');
        expect(span.attributes[SemanticAttributesConstants.userId]?.value,
            'user-id');
        expect(span.attributes[SemanticAttributesConstants.userEmail]?.value,
            'test@example.com');
        expect(span.attributes['custom.scope']?.value, 'scope-value');
        expect(span.attributes[SemanticAttributesConstants.osName]?.value,
            os.name);
        expect(span.attributes[SemanticAttributesConstants.osVersion]?.value,
            os.version);
        expect(
            span.attributes[SemanticAttributesConstants.sentrySegmentName]
                ?.value,
            'test-span');
        expect(
            span.attributes[SemanticAttributesConstants.sentrySegmentId]?.value,
            span.spanId.toString());
      });

      test('does not override existing span attributes', () async {
        fixture.options.environment = 'test-env';
        fixture.options.release = '1.0.0';
        fixture.hub.configureScope((scope) {
          scope.setUser(SentryUser(id: 'user-id'));
          scope.setAttributes(
              {'custom.scope': SentryAttribute.string('scope-value')});
        });

        final span = fixture.createSpan();
        span.setAttribute(SemanticAttributesConstants.sentrySdkName,
            SentryAttribute.string('custom-sdk'));
        span.setAttribute(SemanticAttributesConstants.sentryEnvironment,
            SentryAttribute.string('custom-env'));
        span.setAttribute(SemanticAttributesConstants.userId,
            SentryAttribute.string('custom-user'));
        span.setAttribute(SemanticAttributesConstants.osName,
            SentryAttribute.string('custom-os'));
        span.setAttribute(SemanticAttributesConstants.sentrySegmentName,
            SentryAttribute.string('custom-segment'));
        span.setAttribute(
            'custom.scope', SentryAttribute.string('span-scope-value'));

        await fixture.hub.captureSpan(span);

        expect(
            span.attributes[SemanticAttributesConstants.sentrySdkName]?.value,
            'custom-sdk');
        expect(
            span.attributes[SemanticAttributesConstants.sentryEnvironment]
                ?.value,
            'custom-env');
        expect(span.attributes[SemanticAttributesConstants.userId]?.value,
            'custom-user');
        expect(span.attributes[SemanticAttributesConstants.osName]?.value,
            'custom-os');
        expect(
            span.attributes[SemanticAttributesConstants.sentrySegmentName]
                ?.value,
            'custom-segment');
        expect(span.attributes['custom.scope']?.value, 'span-scope-value');
      });

      test('preserves custom span attributes', () async {
        final span = fixture.createSpan();
        span.setAttribute('my.custom.string', SentryAttribute.string('hello'));
        span.setAttribute('my.custom.int', SentryAttribute.int(42));
        span.setAttribute('my.custom.bool', SentryAttribute.bool(true));
        span.setAttribute('my.custom.double', SentryAttribute.double(3.14));

        await fixture.hub.captureSpan(span);

        expect(span.attributes['my.custom.string']?.value, 'hello');
        expect(span.attributes['my.custom.int']?.value, 42);
        expect(span.attributes['my.custom.bool']?.value, true);
        expect(span.attributes['my.custom.double']?.value, 3.14);
      });
    });

    group('when tracing is enabled in static mode', () {
      setUp(() {
        fixture.options.tracesSampleRate = 1.0;
        fixture.options.traceLifecycle = SentryTraceLifecycle.static;
        fixture.callIntegration();
      });

      test('does not add span enricher to sdk.integrations', () {
        expect(
          fixture.options.sdk.integrations.contains(
              TelemetryEnricherIntegration.spanEnricherIntegrationName),
          isFalse,
        );
      });
    });

    group('when logs are enabled', () {
      setUp(() {
        fixture.options.enableLogs = true;
      });

      test('adds log enricher to sdk.integrations', () {
        fixture.callIntegration();

        expect(
          fixture.options.sdk.integrations.contains(
              TelemetryEnricherIntegration.logEnricherIntegrationName),
          isTrue,
        );
      });

      test('adds os attributes to log', () async {
        fixture.callIntegration();

        final log = fixture.createLog();
        await fixture.hub.captureLog(log);

        final os = getSentryOperatingSystem();

        expect(
            log.attributes[SemanticAttributesConstants.osName]?.value, os.name);
        expect(log.attributes[SemanticAttributesConstants.osVersion]?.value,
            os.version);
      });

      test('does not override existing log attributes', () async {
        fixture.callIntegration();

        fixture.hub.configureScope((scope) {
          scope.setAttributes(
              {'custom.scope': SentryAttribute.string('scope-value')});
        });

        final log = fixture.createLog();
        log.attributes[SemanticAttributesConstants.osName] =
            SentryAttribute.string('custom-os');
        log.attributes['custom.scope'] =
            SentryAttribute.string('log-scope-value');

        await fixture.hub.captureLog(log);

        expect(log.attributes[SemanticAttributesConstants.osName]?.value,
            'custom-os');
        expect(log.attributes['custom.scope']?.value, 'log-scope-value');
      });

      test('preserves custom log attributes', () async {
        fixture.callIntegration();

        final log = fixture.createLog();
        log.attributes['my.custom.string'] = SentryAttribute.string('hello');
        log.attributes['my.custom.int'] = SentryAttribute.int(42);
        log.attributes['my.custom.bool'] = SentryAttribute.bool(true);
        log.attributes['my.custom.double'] = SentryAttribute.double(3.14);

        await fixture.hub.captureLog(log);

        expect(log.attributes['my.custom.string']?.value, 'hello');
        expect(log.attributes['my.custom.int']?.value, 42);
        expect(log.attributes['my.custom.bool']?.value, true);
        expect(log.attributes['my.custom.double']?.value, 3.14);
      });

      group('in streaming mode', () {
        setUp(() {
          fixture.options.tracesSampleRate = 1.0;
          fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
          fixture.callIntegration();
        });

        test('adds parent span id from active span', () async {
          final span = fixture.createSpan();
          fixture.hub.configureScope((scope) {
            scope.setActiveSpan(span);
          });

          final log = fixture.createLog();
          await fixture.hub.captureLog(log);

          expect(
              log
                  .attributes[
                      SemanticAttributesConstants.sentryTraceParentSpanId]
                  ?.value,
              span.spanId.toString());
        });

        test('does not add parent span id when no active span', () async {
          final log = fixture.createLog();
          await fixture.hub.captureLog(log);

          expect(
              log.attributes[
                  SemanticAttributesConstants.sentryTraceParentSpanId],
              isNull);
        });
      });

      group('in static mode', () {
        setUp(() {
          fixture.options.tracesSampleRate = 1.0;
          fixture.options.traceLifecycle = SentryTraceLifecycle.static;
          fixture.callIntegration();
        });

        test('adds parent span id from scope span', () async {
          final transaction = fixture.hub.startTransaction('test', 'test');
          fixture.hub.configureScope((scope) {
            scope.span = transaction;
          });

          final log = fixture.createLog();
          await fixture.hub.captureLog(log);

          expect(
              log
                  .attributes[
                      SemanticAttributesConstants.sentryTraceParentSpanId]
                  ?.value,
              transaction.context.spanId.toString());
        });

        test('does not add parent span id when no scope span', () async {
          final log = fixture.createLog();
          await fixture.hub.captureLog(log);

          expect(
              log.attributes[
                  SemanticAttributesConstants.sentryTraceParentSpanId],
              isNull);
        });
      });
    });

    group('when both tracing and logs are disabled', () {
      setUp(() {
        fixture.options.tracesSampleRate = null;
        fixture.options.enableLogs = false;
        fixture.callIntegration();
      });

      test('does not add enrichers to sdk.integrations', () {
        expect(
          fixture.options.sdk.integrations.contains(
              TelemetryEnricherIntegration.spanEnricherIntegrationName),
          isFalse,
        );
        expect(
          fixture.options.sdk.integrations.contains(
              TelemetryEnricherIntegration.logEnricherIntegrationName),
          isFalse,
        );
      });
    });

    group('close', () {
      test('removes span callback when closed', () async {
        fixture.options.tracesSampleRate = 1.0;
        fixture.options.traceLifecycle = SentryTraceLifecycle.streaming;
        final integration = fixture.getSut();
        integration.call(fixture.hub, fixture.options);

        integration.close();

        // After close, span should not be enriched by this integration
        final span = fixture.createSpan();
        await fixture.hub.captureSpan(span);

        // SDK attributes should NOT be added (integration was closed)
        expect(
            span.attributes[SemanticAttributesConstants.sentrySdkName], isNull);
      });

      test('removes log callback when closed', () async {
        fixture.options.enableLogs = true;
        final integration = fixture.getSut();
        integration.call(fixture.hub, fixture.options);

        integration.close();

        // After close, log should not be enriched by this integration
        final log = fixture.createLog();
        await fixture.hub.captureLog(log);

        // OS attributes should NOT be added by this integration
        // Note: sentry_client.dart still adds SDK attributes, but not OS
        expect(log.attributes[SemanticAttributesConstants.osName], isNull);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  late final hub = Hub(options);

  TelemetryEnricherIntegration getSut() => TelemetryEnricherIntegration();

  void callIntegration() {
    getSut().call(hub, options);
  }

  RecordingSentrySpanV2 createSpan() {
    return RecordingSentrySpanV2.root(
      name: 'test-span',
      traceId: SentryId.newId(),
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }

  SentryLog createLog() {
    return SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {},
    );
  }
}
