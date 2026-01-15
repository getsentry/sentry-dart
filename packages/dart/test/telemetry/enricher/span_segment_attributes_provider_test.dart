import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/enricher/span_segment_attributes_provider.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('SpanSegmentTelemetryAttributesProvider', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('when item is RecordingSentrySpanV2', () {
      test('includes segment ID attribute', () async {
        final provider = fixture.getSut();
        final span = fixture.createSpan();

        final attributes = await provider.attributes(span);

        expect(attributes[SemanticAttributesConstants.sentrySegmentId]?.value,
            span.segmentSpan.spanId.toString());
      });

      test('includes segment name attribute', () async {
        final provider = fixture.getSut();
        final span = fixture.createSpan(name: 'test-operation');

        final attributes = await provider.attributes(span);

        expect(attributes[SemanticAttributesConstants.sentrySegmentName]?.value,
            'test-operation');
      });

      test('uses correct segment span for child spans', () async {
        final provider = fixture.getSut();
        final root = fixture.createSpan(name: 'root-span');
        final child = fixture.createChildSpan(root, name: 'child-span');

        final childAttributes = await provider.attributes(child);

        // Child should use root's span ID as segment ID
        expect(
            childAttributes[SemanticAttributesConstants.sentrySegmentId]?.value,
            root.spanId.toString());
        expect(
            childAttributes[SemanticAttributesConstants.sentrySegmentName]
                ?.value,
            'root-span');
      });

      test('uses correct segment span for deeply nested spans', () async {
        final provider = fixture.getSut();
        final root = fixture.createSpan(name: 'root-span');
        final child = fixture.createChildSpan(root, name: 'child-span');
        final grandchild =
            fixture.createChildSpan(child, name: 'grandchild-span');

        final grandchildAttributes = await provider.attributes(grandchild);

        // Grandchild should still use root's span ID as segment ID
        expect(
            grandchildAttributes[SemanticAttributesConstants.sentrySegmentId]
                ?.value,
            root.spanId.toString());
        expect(
            grandchildAttributes[SemanticAttributesConstants.sentrySegmentName]
                ?.value,
            'root-span');
      });
    });

    test(
        'when item is not RecordingSentrySpanV2 returns empty map for SentryLog',
        () async {
      final provider = fixture.getSut();
      final log = fixture.createLog();

      final attributes = await provider.attributes(log);

      expect(attributes, isEmpty);
    });

    test(
        'when item is not RecordingSentrySpanV2 returns empty map for arbitrary object',
        () async {
      final provider = fixture.getSut();
      final item = Object();

      final attributes = await provider.attributes(item);

      expect(attributes, isEmpty);
    });

    test('when item is not RecordingSentrySpanV2 returns empty map for String',
        () async {
      final provider = fixture.getSut();
      const item = 'test string';

      final attributes = await provider.attributes(item);

      expect(attributes, isEmpty);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  SpanSegmentTelemetryAttributesProvider getSut() {
    return SpanSegmentTelemetryAttributesProvider();
  }

  RecordingSentrySpanV2 createSpan({String name = 'test-span'}) {
    return RecordingSentrySpanV2.root(
      name: name,
      traceId: SentryId.newId(),
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (_) =>
          SentryTraceContextHeader(SentryId.newId(), 'publicKey'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }

  RecordingSentrySpanV2 createChildSpan(
    RecordingSentrySpanV2 parent, {
    String name = 'child-span',
  }) {
    return RecordingSentrySpanV2.child(
      parent: parent,
      name: name,
      onSpanEnd: (_) {},
      clock: options.clock,
      dscCreator: (_) =>
          SentryTraceContextHeader(SentryId.newId(), 'publicKey'),
    );
  }

  SentryLog createLog() {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: 'test log',
      attributes: <String, SentryAttribute>{},
    );
  }
}
