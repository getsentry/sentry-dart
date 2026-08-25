import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/log/default_logger.dart';
import 'package:sentry/src/telemetry/log/logger_setup_integration.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

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

  late final Hub hub;
  late final LoggerSetupIntegration sut;

  Fixture() {
    hub = Hub(options);
    sut = LoggerSetupIntegration();
  }
}

class _CustomSentryLogger implements SentryLogger {
  @override
  FutureOr<void> trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> info(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> error(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  SentryLoggerFormatter get fmt => _CustomSentryLoggerFormatter();
}

class _CustomSentryLoggerFormatter implements SentryLoggerFormatter {
  @override
  FutureOr<void> trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}

  @override
  FutureOr<void> fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {}
}
