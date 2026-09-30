import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/log/default_logger.dart';
import 'package:sentry/src/telemetry/log/logger_setup_integration.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';
import '../../mocks/mock_sentry_client.dart';

void main() {
  group('$LoggerSetupIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('configures DefaultSentryLogger', () {
      fixture.sut.call(fixture.hub, fixture.options);

      expect(fixture.options.logger, isA<DefaultSentryLogger>());
    });

    test('correlates telemetry with nested streaming spans', () async {
      fixture.options.tracesSampleRate = 1.0;
      fixture.sut.call(fixture.hub, fixture.options);
      await fixture.hub.startSpan('parent', (parent) async {
        await fixture.hub.startSpan('child', (child) async {
          fixture.options.logger.info('message');
          await Future<void>.delayed(Duration.zero);

          final telemetry = fixture.client.captureLogCalls.map(
            (call) => call.log,
          );
          expect(telemetry, isNotEmpty);
          for (final item in telemetry) {
            expect(item.spanId, child.spanId);
            expect(item.traceId, child.traceId);
          }
        });
      });
    });

    test('correlates telemetry with the active idle span', () async {
      fixture.options.tracesSampleRate = 1.0;
      fixture.sut.call(fixture.hub, fixture.options);
      final span = fixture.hub.startIdleSpan('idle');
      addTearDown(span.end);

      fixture.options.logger.info('message');
      await Future<void>.delayed(Duration.zero);

      final telemetry = fixture.client.captureLogCalls.map((call) => call.log);
      expect(telemetry, isNotEmpty);
      for (final item in telemetry) {
        expect(item.spanId, span.spanId);
        expect(item.traceId, span.traceId);
      }
    });

    test('preserves static transaction correlation', () async {
      fixture.options
        ..traceLifecycle = SentryTraceLifecycle.static
        ..tracesSampleRate = 1.0;
      fixture.sut.call(fixture.hub, fixture.options);
      final span = fixture.hub.startTransaction(
        'parent',
        'test',
        bindToScope: true,
      );
      addTearDown(span.finish);

      fixture.options.logger.info('message');
      await Future<void>.delayed(Duration.zero);

      final telemetry = fixture.client.captureLogCalls.map((call) => call.log);
      expect(telemetry, isNotEmpty);
      for (final item in telemetry) {
        expect(item.spanId, span.context.spanId);
      }
    });

    test('adds integration to SDK', () {
      fixture.sut.call(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.integrations,
        contains(LoggerSetupIntegration.integrationName),
      );
    });

    test('does not override existing non-noop logger', () {
      final customLogger = _CustomSentryLogger();
      fixture.options.logger = customLogger;

      fixture.sut.call(fixture.hub, fixture.options);

      expect(fixture.options.logger, same(customLogger));
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  final client = MockSentryClient();

  late final Hub hub;
  late final LoggerSetupIntegration sut;

  Fixture() {
    hub = Hub(options)..bindClient(client);
    sut = LoggerSetupIntegration();
  }
}

class _CustomSentryLogger implements SentryLogger {
  @override
  void trace(String body, {Map<String, SentryAttribute>? attributes}) {}

  @override
  void debug(String body, {Map<String, SentryAttribute>? attributes}) {}

  @override
  void info(String body, {Map<String, SentryAttribute>? attributes}) {}

  @override
  void warn(String body, {Map<String, SentryAttribute>? attributes}) {}

  @override
  void error(String body, {Map<String, SentryAttribute>? attributes}) {}

  @override
  void fatal(String body, {Map<String, SentryAttribute>? attributes}) {}

  @override
  SentryLoggerFormatter get fmt => _CustomSentryLoggerFormatter();
}

class _CustomSentryLoggerFormatter implements SentryLoggerFormatter {
  @override
  void trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  void fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}
}
