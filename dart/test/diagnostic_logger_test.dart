import 'package:sentry/sentry.dart';
import 'package:sentry/src/diagnostic_logger.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('$DiagnosticLogger do not log if debug is disabled', () {
    fixture.options.debug = false;

    fixture.getSut().log(SentryLevel.error, 'foobar');

    expect(fixture.loggedMessage, isNull);
  });

  test('$DiagnosticLogger log if debug is enabled', () {
    fixture.options.debug = true;

    fixture.getSut().log(SentryLevel.error, 'foobar');

    expect(fixture.loggedMessage, 'foobar');
  });

  test('$DiagnosticLogger do not log if level is too low', () {
    fixture.options.debug = true;
    fixture.options.diagnosticLevel = SentryLevel.error;

    fixture.getSut().log(SentryLevel.warning, 'foobar');

    expect(fixture.loggedMessage, isNull);
  });

  test('$DiagnosticLogger always log fatal', () {
    fixture.options.debug = false;

    fixture.getSut().log(SentryLevel.fatal, 'foobar');

    expect(fixture.loggedMessage, 'foobar');
  });
}

class Fixture {
  var options = defaultTestOptions();

  Object? loggedMessage;

  DiagnosticLogger getSut() {
    return DiagnosticLogger(mockLogger, options);
  }

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedMessage = message;
  }
}
