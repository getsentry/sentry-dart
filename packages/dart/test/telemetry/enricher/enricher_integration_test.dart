import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/enricher/enricher_integration.dart';
import 'package:sentry/src/telemetry/span/sentry_span_v2.dart';
import 'package:test/test.dart';

import '../../mocks/mock_hub.dart';
import '../../test_utils.dart';

void main() {
  group('CoreTelemetryAttributesIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('registers CommonTelemetryAttributesProvider', () async {
      final options = fixture.options;
      final log = fixture.createLog();

      fixture.getSut().call(fixture.hub, options);

      await options.telemetryEnricher.enrichLog(log);

      expect(
          log.attributes[SemanticAttributesConstants.sentrySdkName], isNotNull);
    });

    test('registers SpanSegmentTelemetryAttributesProvider', () async {
      final options = fixture.options;
      final span = fixture.createSpan();

      fixture.getSut().call(fixture.hub, options);

      await options.telemetryEnricher.enrichSpan(span);

      expect(span.attributes[SemanticAttributesConstants.sentrySegmentId],
          isNotNull);
      expect(span.attributes[SemanticAttributesConstants.sentrySegmentName],
          isNotNull);
    });

    test('adds integration name to SDK', () {
      final options = fixture.options;

      fixture.getSut().call(fixture.hub, options);

      expect(
        options.sdk.integrations,
        contains(CoreTelemetryAttributesIntegration.integrationName),
      );
    });

    test('providers are registered in telemetryEnricher', () async {
      final options = fixture.options;

      fixture.getSut().call(fixture.hub, options);

      final log = fixture.createLog();
      await options.telemetryEnricher.enrichLog(log);

      expect(
          log.attributes[SemanticAttributesConstants.sentrySdkName], isNotNull);
      expect(log.attributes[SemanticAttributesConstants.sentrySdkVersion],
          isNotNull);
    });

    test('does not duplicate providers on multiple calls', () async {
      final options = fixture.options;
      final integration = fixture.getSut();

      integration.call(fixture.hub, options);
      integration.call(fixture.hub, options);

      final log = fixture.createLog();
      await options.telemetryEnricher.enrichLog(log);

      expect(
          log.attributes[SemanticAttributesConstants.sentrySdkName], isNotNull);
    });
  });
}

class Fixture {
  final hub = MockHub();
  late SentryOptions options;

  Fixture() {
    options = defaultTestOptions();
  }

  CoreTelemetryAttributesIntegration getSut() {
    return CoreTelemetryAttributesIntegration();
  }

  SentryLog createLog() {
    return SentryLog(
      timestamp: DateTime.now().toUtc(),
      level: SentryLogLevel.info,
      body: 'test log',
      attributes: <String, SentryAttribute>{},
    );
  }

  RecordingSentrySpanV2 createSpan() {
    return RecordingSentrySpanV2.root(
      name: 'test-span',
      traceId: SentryId.newId(),
      onSpanEnd: (_) async {},
      clock: options.clock,
      dscCreator: (_) =>
          SentryTraceContextHeader(SentryId.newId(), 'publicKey'),
      samplingDecision: SentryTracesSamplingDecision(true),
    );
  }
}
