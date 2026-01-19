import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/span/span_capture_pipeline.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:test/test.dart';

import '../../mocks/mock_telemetry_processor.dart';
import '../../test_utils.dart';

void main() {
  group('$SpanCapturePipeline', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when capturing a span', () {
      test('forwards to telemetry processor', () async {
        final span = fixture.createRecordingSpan();
        await fixture.pipeline.captureSpan(span, fixture.scope);

        expect(fixture.processor.addedSpans.length, 1);
        expect(fixture.processor.addedSpans.first, same(span));
      });

      test('adds default attributes and segment metadata for recording spans',
          () async {
        await fixture.scope.setUser(SentryUser(id: 'user-id'));
        fixture.scope.setAttributes({
          'scope-key': SentryAttribute.string('scope'),
          'custom': SentryAttribute.string('scope-custom'),
        });

        final span = fixture.createRecordingSpan();
        span.setAttributes({
          'custom': SentryAttribute.string('span-custom'),
          SemanticAttributesConstants.sentryRelease:
              SentryAttribute.string('span-release'),
        });

        await fixture.pipeline.captureSpan(span, fixture.scope);

        final attributes = span.attributes;
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'test-env');
        expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
            'span-release');
        expect(attributes[SemanticAttributesConstants.sentrySdkName]?.value,
            fixture.options.sdk.name);
        expect(attributes[SemanticAttributesConstants.sentrySdkVersion]?.value,
            fixture.options.sdk.version);
        expect(
            attributes[SemanticAttributesConstants.userId]?.value, 'user-id');
        expect(attributes[SemanticAttributesConstants.sentrySegmentName]?.value,
            span.segmentSpan.name);
        expect(attributes[SemanticAttributesConstants.sentrySegmentId]?.value,
            span.segmentSpan.spanId.toString());
      });

      test('prefers scope attributes over defaults', () async {
        fixture.scope.setAttributes({
          SemanticAttributesConstants.sentryEnvironment:
              SentryAttribute.string('scope-env'),
        });

        final span = fixture.createRecordingSpan();
        span.setAttribute(
          SemanticAttributesConstants.sentryEnvironment,
          SentryAttribute.string('scope-env'),
        );

        await fixture.pipeline.captureSpan(span, fixture.scope);

        final attributes = span.attributes;
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'scope-env');
        expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
            'test-release');
      });

      test('keeps attributes added by lifecycle callbacks', () async {
        fixture.options.lifecycleRegistry
            .registerCallback<ProcessSpan>((event) {
          event.span.setAttribute(
            'callback-key',
            SentryAttribute.string('callback-value'),
          );
          event.span.setAttribute(
            SemanticAttributesConstants.sentryEnvironment,
            SentryAttribute.string('callback-env'),
          );
        });

        final span = fixture.createRecordingSpan();
        await fixture.pipeline.captureSpan(span, fixture.scope);

        final attributes = span.attributes;
        expect(attributes['callback-key']?.value, 'callback-value');
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'callback-env');
      });

      test(
          'attributes set by lifecycle callbacks are not overridden by default attributes',
          () async {
        fixture.options.release = 'random-release';
        fixture.options.lifecycleRegistry
            .registerCallback<ProcessSpan>((event) {
          event.span.setAttribute(
            SemanticAttributesConstants.sentryRelease,
            SentryAttribute.string('release-from-lifecycle-callback'),
          );
        });

        final span = fixture.createRecordingSpan();
        await fixture.pipeline.captureSpan(span, fixture.scope);

        final attributes = span.attributes;
        expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
            'release-from-lifecycle-callback');
      });

      test('does not add user attributes when sendDefaultPii is false',
          () async {
        fixture.options.sendDefaultPii = false;
        await fixture.scope.setUser(SentryUser(id: 'user-id'));

        final span = fixture.createRecordingSpan();
        await fixture.pipeline.captureSpan(span, fixture.scope);

        final attributes = span.attributes;
        expect(attributes.containsKey(SemanticAttributesConstants.userId),
            isFalse);
      });

      test('does not add spans to processor for no-op spans', () async {
        await fixture.pipeline
            .captureSpan(const NoOpSentrySpanV2(), fixture.scope);

        expect(fixture.processor.addedSpans, isEmpty);
      });

      test('does not add spans to processor for unset spans', () async {
        await fixture.pipeline
            .captureSpan(const UnsetSentrySpanV2(), fixture.scope);

        expect(fixture.processor.addedSpans, isEmpty);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..environment = 'test-env'
    ..release = 'test-release'
    ..traceLifecycle = SentryTraceLifecycle.streaming
    ..sendDefaultPii = true;
  final processor = MockTelemetryProcessor();

  late final Scope scope;
  late final SpanCapturePipeline pipeline;

  Fixture() {
    options.telemetryProcessor = processor;
    scope = Scope(options);
    pipeline = SpanCapturePipeline(options);
  }

  RecordingSentrySpanV2 createRecordingSpan({String name = 'test-span'}) {
    return RecordingSentrySpanV2.root(
      name: name,
      traceId: SentryId.newId(),
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (s) => SentryTraceContextHeader(SentryId.newId(), 'key'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }
}
