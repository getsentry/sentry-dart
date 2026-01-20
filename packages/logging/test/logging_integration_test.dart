import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:sentry_logging/src/version.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'mock_hub.dart';

void main() {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture();
    // Set Logger.root level to allow all logs for testing
    Logger.root.level = Level.ALL;
  });

  test('options.sdk.integrations contains $LoggingIntegration', () async {
    final sut = fixture.createSut();
    sut.call(fixture.hub, fixture.options);
    await sut.close();
    expect(
      fixture.options.sdk.integrations.contains('LoggingIntegration'),
      true,
    );
  });

  test('options.sdk.integrations contains version', () async {
    final sut = fixture.createSut();
    sut.call(fixture.hub, fixture.options);
    await sut.close();

    final package =
        fixture.options.sdk.packages.firstWhere((it) => it.name == packageName);
    expect(package.name, packageName);
    expect(package.version, sdkVersion);
  });

  test('logger gets recorded if level over minlevel', () {
    final sut = fixture.createSut(minBreadcrumbLevel: Level.CONFIG);
    sut.call(fixture.hub, fixture.options);

    final log = Logger('FooBarLogger');
    log.warning('A log message');

    expect(fixture.hub.events.length, 0);
    expect(fixture.hub.breadcrumbs.length, 1);
    final crumb = fixture.hub.breadcrumbs.first.breadcrumb;
    expect(crumb.level, SentryLevel.warning);
    expect(crumb.message, 'A log message');
    expect(crumb.data, <String, dynamic>{
      'LogRecord.loggerName': 'FooBarLogger',
      'LogRecord.sequenceNumber': isNotNull,
    });
    expect(crumb.timestamp, isNotNull);
    expect(crumb.category, 'log');
    expect(crumb.type, 'debug');
  });

  test('logger gets recorded if level equal minlevel', () {
    final sut = fixture.createSut(minBreadcrumbLevel: Level.INFO);
    sut.call(fixture.hub, fixture.options);

    final log = Logger('FooBarLogger');
    log.info('A log message');

    expect(fixture.hub.events.length, 0);
    expect(fixture.hub.breadcrumbs.length, 1);
  });

  test('passes log records as hints', () {
    final sut = fixture.createSut(
      minBreadcrumbLevel: Level.INFO,
      minEventLevel: Level.WARNING,
    );
    sut.call(fixture.hub, fixture.options);
    final logger = Logger('FooBarLogger');

    logger.info(
      'An info message',
    );

    expect(fixture.hub.breadcrumbs.length, 1);
    final breadcrumbHint =
        fixture.hub.breadcrumbs.first.hint?.get('record') as LogRecord;

    expect(breadcrumbHint.level, Level.INFO);
    expect(breadcrumbHint.message, 'An info message');

    final exception = Exception('foo bar');
    final stackTrace = StackTrace.current;
    logger.warning(
      'A log message',
      exception,
      stackTrace,
    );

    expect(fixture.hub.events.length, 1);
    final errorHint = fixture.hub.events.first.hint?.get('record') as LogRecord;

    expect(errorHint.level, Level.WARNING);
    expect(errorHint.message, 'A log message');
    expect(errorHint.error, exception);
    expect(errorHint.stackTrace, stackTrace);
  });

  test('logger gets not recorded if level under minlevel', () {
    final sut = fixture.createSut(minBreadcrumbLevel: Level.SEVERE);
    sut.call(fixture.hub, fixture.options);

    final log = Logger('FooBarLogger');
    log.warning('A log message');

    expect(fixture.hub.events.length, 0);
    expect(fixture.hub.breadcrumbs.length, 0);
  });

  test('Level.Off is never recorded as breadcrumb', () {
    // even if everything should be logged, Level.Off is never logged
    final sut = fixture.createSut(minBreadcrumbLevel: Level.ALL);
    sut.call(fixture.hub, fixture.options);

    final log = Logger('FooBarLogger');
    log.log(Level.OFF, 'A log message');

    expect(fixture.hub.events.length, 0);
    expect(fixture.hub.breadcrumbs.length, 0);
  });

  test('exception is recorded as event if minEventLevel over minlevel', () {
    final sut = fixture.createSut(minEventLevel: Level.INFO);
    sut.call(fixture.hub, fixture.options);

    final exception = Exception('foo bar');
    final stackTrace = StackTrace.current;

    final log = Logger('FooBarLogger');
    log.warning(
      'A log message',
      exception,
      stackTrace,
    );
    expect(fixture.hub.events.length, 1);
    expect(fixture.hub.events.first.event.breadcrumbs, null);
    final event = fixture.hub.events.first.event;
    expect(event.level, SentryLevel.warning);
    expect(event.logger, 'FooBarLogger');
    expect(event.throwable, exception);
    // ignore: deprecated_member_use
    expect(event.extra?['LogRecord.sequenceNumber'], isNotNull);
    expect(fixture.hub.events.first.stackTrace, stackTrace);
  });

  test('exception is recorded as event if minEventLevel equal minlevel', () {
    final sut = fixture.createSut(minEventLevel: Level.INFO);
    sut.call(fixture.hub, fixture.options);

    final exception = Exception('foo bar');
    final stackTrace = StackTrace.current;

    final log = Logger('FooBarLogger');
    log.info(
      'A log message',
      exception,
      stackTrace,
    );
    expect(fixture.hub.events.length, 1);
    expect(fixture.hub.events.first.event.breadcrumbs, null);
  });

  test('exception is not recorded as event if minEventLevel under minlevel',
      () {
    final sut = fixture.createSut(minEventLevel: Level.SEVERE);
    sut.call(fixture.hub, fixture.options);

    final exception = Exception('foo bar');
    final stackTrace = StackTrace.current;

    final log = Logger('FooBarLogger');
    log.warning(
      'A log message',
      exception,
      stackTrace,
    );
    expect(fixture.hub.events.length, 0);
  });

  test('Level.Off is never sent as event', () {
    // even if everything should be logged, Level.Off is never logged
    final sut = fixture.createSut(minEventLevel: Level.ALL);
    sut.call(fixture.hub, fixture.options);

    final exception = Exception('foo bar');
    final stackTrace = StackTrace.current;

    final log = Logger('FooBarLogger');
    log.log(
      Level.OFF,
      'A log message',
      exception,
      stackTrace,
    );
    expect(fixture.hub.events.length, 0);
  });

  group('Sentry logger integration', () {
    test('does not call sentry logger when enableLogs is false', () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = false;

      final sut = fixture.createSut(minSentryLogLevel: Level.INFO);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');
      log.severe('Test message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(mockLogger.errorCalls.length, 0);
    });

    test(
        'calls sentry logger when enableLogs is true and level meets threshold',
        () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.INFO);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');
      log.severe('Test message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(mockLogger.errorCalls.length, 1);
      expect(mockLogger.errorCalls.first.message, 'Test message');
    });

    test('does not call sentry logger when level is below threshold', () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.SEVERE);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');
      log.info('Test message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(mockLogger.infoCalls.length, 0);
    });

    test('maps all log levels to correct sentry logger methods', () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.ALL);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');

      // Test error level mappings
      log.shout('SHOUT message');
      log.severe('SEVERE message');

      // Test warn level mapping
      log.warning('WARNING message');

      // Test info level mapping
      log.info('INFO message');

      // Test debug level mappings
      log.config('CONFIG message');
      log.fine('FINE message');
      log.finer('FINER message');
      log.finest('FINEST message');
      log.log(Level.ALL, 'ALL message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      // Verify error mappings (SHOUT and SEVERE -> error)
      expect(mockLogger.errorCalls.length, 2);
      expect(mockLogger.errorCalls[0].message, 'SHOUT message');
      expect(mockLogger.errorCalls[1].message, 'SEVERE message');

      // Verify warn mapping (WARNING -> warn)
      expect(mockLogger.warnCalls.length, 1);
      expect(mockLogger.warnCalls.first.message, 'WARNING message');

      // Verify info mapping (INFO -> info)
      expect(mockLogger.infoCalls.length, 1);
      expect(mockLogger.infoCalls.first.message, 'INFO message');

      // Verify trace mappings (FINER, FINEST -> trace)
      expect(mockLogger.traceCalls.length, 2);
      expect(mockLogger.traceCalls[0].message, 'FINER message');
      expect(mockLogger.traceCalls[1].message, 'FINEST message');

      // Verify debug mappings (CONFIG, FINE, ALL -> debug)
      expect(mockLogger.debugCalls.length, 3);
      expect(mockLogger.debugCalls[0].message, 'CONFIG message');
      expect(mockLogger.debugCalls[1].message, 'FINE message');
      expect(mockLogger.debugCalls[2].message, 'ALL message');
    });

    test('includes all expected attributes in sentry logger calls', () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.INFO);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');

      // Test basic attributes (without error)
      log.info('Basic message');

      // Test with error and stackTrace (stackTrace won't be in attributes)
      final stackTrace = StackTrace.current;
      final exception = Exception('test error');
      log.severe('Message with error and stack', exception, stackTrace);

      await Future<void>.delayed(Duration(milliseconds: 10));

      // Verify basic attributes are always present
      expect(mockLogger.infoCalls.length, 1);
      final basicAttributes = mockLogger.infoCalls.first.attributes!;
      expect(basicAttributes['loggerName']?.value, 'TestLogger');
      expect(basicAttributes['sequenceNumber']?.value, isA<int>());
      expect(basicAttributes['time']?.value, isA<int>());
      expect(
        basicAttributes['sentry.origin']?.value,
        LoggingIntegration.origin,
      );
      expect(basicAttributes.containsKey('error'), false);
      expect(basicAttributes.containsKey('stackTrace'), false);

      // Verify error/stacktrace attributes are not included when present
      expect(mockLogger.errorCalls.length, 1);
      final fullAttributes = mockLogger.errorCalls.first.attributes!;
      expect(fullAttributes.containsKey('error'), false);
      expect(fullAttributes.containsKey('stackTrace'), false);
    });

    test('Level.OFF is never sent to sentry logger', () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.ALL);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');
      log.log(Level.OFF, 'Test message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(mockLogger.errorCalls.length, 0);
      expect(mockLogger.warnCalls.length, 0);
      expect(mockLogger.infoCalls.length, 0);
      expect(mockLogger.debugCalls.length, 0);
      expect(mockLogger.traceCalls.length, 0);
    });

    test('minSentryLogLevel is respected', () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.WARNING);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');

      // This should not be logged (below threshold)
      log.info('Info message');

      // This should be logged (meets threshold)
      log.warning('Warning message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(mockLogger.infoCalls.length, 0);
      expect(mockLogger.warnCalls.length, 1);
      expect(mockLogger.warnCalls.first.message, 'Warning message');
    });

    test('handles custom Level instances correctly using numeric values',
        () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.ALL);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');

      // Create custom levels with different numeric values
      final customError =
          Level('CUSTOM_ERROR', 1200); // >= SEVERE (1000) -> error
      final customWarn = Level('CUSTOM_WARN', 950); // >= WARNING (900) -> warn
      final customInfo = Level('CUSTOM_INFO', 850); // >= INFO (800) -> info
      final customDebug =
          Level('CUSTOM_DEBUG', 750); // >= CONFIG (700) -> debug
      final customTrace = Level('CUSTOM_TRACE', 600); // < CONFIG (700) -> trace

      // Test each custom level
      log.log(customError, 'Custom error message');
      log.log(customWarn, 'Custom warn message');
      log.log(customInfo, 'Custom info message');
      log.log(customDebug, 'Custom debug message');
      log.log(customTrace, 'Custom trace message');

      await Future<void>.delayed(Duration(milliseconds: 10));

      // Verify mappings
      expect(mockLogger.errorCalls.length, 1);
      expect(mockLogger.errorCalls.first.message, 'Custom error message');

      expect(mockLogger.warnCalls.length, 1);
      expect(mockLogger.warnCalls.first.message, 'Custom warn message');

      expect(mockLogger.infoCalls.length, 1);
      expect(mockLogger.infoCalls.first.message, 'Custom info message');

      expect(mockLogger.debugCalls.length, 1);
      expect(mockLogger.debugCalls.first.message, 'Custom debug message');

      expect(mockLogger.traceCalls.length, 1);
      expect(mockLogger.traceCalls.first.message, 'Custom trace message');
    });

    test('custom Level instances respect minSentryLogLevel threshold',
        () async {
      final mockLogger = MockSentryLogger();
      final options = TestSentryOptions(mockLogger)..enableLogs = true;

      final sut = fixture.createSut(minSentryLogLevel: Level.WARNING);
      sut.call(fixture.hub, options);

      final log = Logger('TestLogger');

      // Create custom levels
      final customAboveThreshold =
          Level('CUSTOM_HIGH', 950); // >= WARNING (900)
      final customBelowThreshold = Level('CUSTOM_LOW', 850); // < WARNING (900)

      log.log(customAboveThreshold, 'Should be logged');
      log.log(customBelowThreshold, 'Should not be logged');

      await Future<void>.delayed(Duration(milliseconds: 10));

      // Only the custom level above threshold should be logged
      expect(mockLogger.warnCalls.length, 1);
      expect(mockLogger.warnCalls.first.message, 'Should be logged');

      // No other log levels should have been called
      expect(mockLogger.errorCalls.length, 0);
      expect(mockLogger.infoCalls.length, 0);
      expect(mockLogger.debugCalls.length, 0);
      expect(mockLogger.traceCalls.length, 0);
    });
  });
}

class Fixture {
  SentryOptions options = defaultTestOptions();
  MockHub hub = MockHub();

  LoggingIntegration createSut({
    Level minBreadcrumbLevel = Level.INFO,
    Level minEventLevel = Level.SEVERE,
    Level minSentryLogLevel = Level.SEVERE,
  }) {
    return LoggingIntegration(
      minBreadcrumbLevel: minBreadcrumbLevel,
      minEventLevel: minEventLevel,
      minSentryLogLevel: minSentryLogLevel,
    );
  }
}

class MockSentryLogger implements SentryLogger {
  final List<MockLogCall> traceCalls = [];
  final List<MockLogCall> debugCalls = [];
  final List<MockLogCall> infoCalls = [];
  final List<MockLogCall> warnCalls = [];
  final List<MockLogCall> errorCalls = [];
  final List<MockLogCall> fatalCalls = [];

  @override
  Future<void> trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) async {
    traceCalls.add(MockLogCall(body, attributes));
  }

  @override
  Future<void> debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) async {
    debugCalls.add(MockLogCall(body, attributes));
  }

  @override
  Future<void> info(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) async {
    infoCalls.add(MockLogCall(body, attributes));
  }

  @override
  Future<void> warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) async {
    warnCalls.add(MockLogCall(body, attributes));
  }

  @override
  Future<void> error(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) async {
    errorCalls.add(MockLogCall(body, attributes));
  }

  @override
  Future<void> fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) async {
    fatalCalls.add(MockLogCall(body, attributes));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLogCall {
  final String message;
  final Map<String, SentryAttribute>? attributes;

  MockLogCall(this.message, this.attributes);
}

class TestSentryOptions extends SentryOptions {
  @override
  // ignore: overridden_fields
  late final SentryLogger logger;

  TestSentryOptions(SentryLogger mockLogger)
      : super(dsn: 'https://abc@def.ingest.sentry.io/1234567') {
    logger = mockLogger;
    // ignore: invalid_use_of_internal_member
    automatedTestMode = true;
  }
}
