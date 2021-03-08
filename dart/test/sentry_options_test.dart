import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_client.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  test('$Client is NoOp', () {
    final options = SentryOptions(dsn: fakeDsn);
    expect(NoOpClient(), options.httpClient);
  });

  test('$Client sets a custom client', () {
    final options = SentryOptions(dsn: fakeDsn);

    final client = Client();
    options.httpClient = client;
    expect(client, options.httpClient);
  });

  test('maxBreadcrumbs is 100 by default', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(100, options.maxBreadcrumbs);
  });

  test('maxBreadcrumbs sets custom maxBreadcrumbs', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.maxBreadcrumbs = 200;

    expect(200, options.maxBreadcrumbs);
  });

  test('$SentryLogger is NoOp by default', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(noOpLogger, options.logger);
  });

  test('$SentryLogger sets a diagnostic logger', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.logger = dartLogger;

    expect(false, options.logger == noOpLogger);
  });
}
