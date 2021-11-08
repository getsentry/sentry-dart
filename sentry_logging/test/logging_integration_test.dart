import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_logging/sentry_logging.dart';
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
    await sut.call(fixture.hub, fixture.options);
    await sut.close();
    expect(
      fixture.options.sdk.integrations.contains('LoggingIntegration'),
      true,
    );
  });

  test('logger gets recorded', () async {
    final sut = fixture.createSut();
    await sut.call(fixture.hub, fixture.options);

    final log = Logger('FooBarLogger');
    log.warning(
      'A log message',
    );

    expect(fixture.hub.events.length, 0);
    expect(fixture.hub.breadcrumbs.length, 1);
    final crumb = fixture.hub.breadcrumbs.first;
    expect(crumb.level, SentryLevel.warning);
    expect(crumb.message, 'A log message');
    expect(crumb.data, <String, dynamic>{
      'LogRecord.loggerName': 'FooBarLogger',
      'LogRecord.sequenceNumber': 0,
    });
    expect(crumb.timestamp, isNotNull);
    expect(crumb.category, 'log');
    expect(crumb.type, 'debug');
  });

  test('exceptions is recorded as breadcrumb if logExceptionsAsEvents = false',
      () async {
    final sut = fixture.createSut(logExceptionsAsEvents: false);
    await sut.call(fixture.hub, fixture.options);

    final log = Logger('FooBarLogger');
    log.warning(
      'A log message',
      Exception('foo bar'),
      StackTrace.current,
    );
    expect(fixture.hub.events.length, 0);
    expect(fixture.hub.breadcrumbs.length, 1);
    final crumb = fixture.hub.breadcrumbs.first;
    expect(crumb.data?.length, 4);
  });

  test('exceptions is recorded as event if logExceptionsAsEvents = true',
      () async {
    final sut = fixture.createSut(logExceptionsAsEvents: true);
    await sut.call(fixture.hub, fixture.options);

    final exception = Exception('foo bar');
    final stackTrace = StackTrace.current;

    final log = Logger('FooBarLogger');
    log.warning(
      'A log message',
      exception,
      stackTrace,
    );
    expect(fixture.hub.breadcrumbs.length, 0);
    expect(fixture.hub.events.length, 1);
    final event = fixture.hub.events.first.event;
    expect(event.level, SentryLevel.warning);
    expect(event.logger, 'FooBarLogger');
    expect(event.throwable, exception);
    expect(event.extra?['LogRecord.sequenceNumber'], isNotNull);
    expect(fixture.hub.events.first.stackTrace, stackTrace);
  });
}

class Fixture {
  SentryOptions options = SentryOptions(dsn: fakeDsn);
  MockHub hub = MockHub();

  LoggingIntegration createSut({bool logExceptionsAsEvents = true}) {
    return LoggingIntegration(logExceptionAsEvent: logExceptionsAsEvents);
  }
}
