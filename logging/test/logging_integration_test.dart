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
}

class Fixture {
  SentryOptions options = defaultTestOptions();
  MockHub hub = MockHub();

  LoggingIntegration createSut({
    Level minBreadcrumbLevel = Level.INFO,
    Level minEventLevel = Level.SEVERE,
  }) {
    return LoggingIntegration(
      minBreadcrumbLevel: minBreadcrumbLevel,
      minEventLevel: minEventLevel,
    );
  }
}
