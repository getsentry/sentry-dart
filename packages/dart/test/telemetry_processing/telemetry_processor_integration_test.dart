import 'package:sentry/sentry.dart';
import 'package:sentry/src/spans_v2/sentry_span_v2.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor_integration.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('DefaultTelemetryProcessorIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds itself to sdk.integrations', () {
      fixture.addIntegration();

      expect(
        fixture.options.sdk.integrations
            .contains(DefaultTelemetryProcessorIntegration.integrationName),
        true,
      );
    });

    test('sets DefaultTelemetryProcessor on options', () {
      expect(fixture.options.telemetryProcessor, isA<NoOpTelemetryProcessor>());

      fixture.addIntegration();

      expect(
          fixture.options.telemetryProcessor, isA<DefaultTelemetryProcessor>());
    });

    test('does not replace existing non-NoOpTelemetryProcessor', () {
      final customProcessor = _MockTelemetryProcessor();
      fixture.options.telemetryProcessor = customProcessor;

      fixture.addIntegration();

      expect(fixture.options.telemetryProcessor, same(customProcessor));
      expect(
        fixture.options.sdk.integrations
            .contains(DefaultTelemetryProcessorIntegration.integrationName),
        false,
      );
    });

    test('creates processor with log and span buffers', () {
      fixture.addIntegration();

      final processor =
          fixture.options.telemetryProcessor as DefaultTelemetryProcessor;
      expect(processor.logBuffer, isNotNull);
      expect(processor.spanBuffer, isNotNull);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  late final hub = Hub(options);
  late final DefaultTelemetryProcessorIntegration integration;

  Fixture() {
    integration = DefaultTelemetryProcessorIntegration();
  }

  void addIntegration() {
    integration.call(hub, options);
  }
}

class _MockTelemetryProcessor implements TelemetryProcessor {
  @override
  void addLog(SentryLog log) {}

  @override
  void addSpan(RecordingSentrySpanV2 span) {}

  @override
  void flush() {}
}
