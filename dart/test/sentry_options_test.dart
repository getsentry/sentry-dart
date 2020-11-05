import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_client.dart';
import 'package:test/test.dart';

void main() {
  test('$Client is NoOp', () {
    final options = SentryOptions();
    expect(NoOpClient(), options.httpClient);
  });

  test('$Client is NoOp if null is set', () {
    final options = SentryOptions();
    options.httpClient = null;
    expect(NoOpClient(), options.httpClient);
  });

  test('$Client sets a custom client', () {
    final options = SentryOptions();

    final client = Client();
    options.httpClient = client;
    expect(client, options.httpClient);
  });

  test('maxBreadcrumbs is 100 by default', () {
    final options = SentryOptions();

    expect(100, options.maxBreadcrumbs);
  });

  test('maxBreadcrumbs is default if null is set', () {
    final options = SentryOptions();
    options.maxBreadcrumbs = null;

    expect(100, options.maxBreadcrumbs);
  });

  test('maxBreadcrumbs is default if negative number is set', () {
    final options = SentryOptions();
    options.maxBreadcrumbs = -1;

    expect(100, options.maxBreadcrumbs);
  });

  test('maxBreadcrumbs sets custom maxBreadcrumbs', () {
    final options = SentryOptions();
    options.maxBreadcrumbs = 200;

    expect(200, options.maxBreadcrumbs);
  });

  test('$Logger is NoOp by default', () {
    final options = SentryOptions();

    expect(noOpLogger, options.logger);
  });

  test('$Logger is NoOp if null is set', () {
    final options = SentryOptions();
    options.logger = null;

    expect(noOpLogger, options.logger);
  });

  test('$Logger sets a diagnostic logger', () {
    final options = SentryOptions();
    options.logger = dartLogger;

    expect(false, options.logger == noOpLogger);
  });
}
