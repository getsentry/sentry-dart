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

  test('SentryLogger sets a diagnostic logger', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.logger = dartLogger;

    expect(false, options.logger == noOpLogger);
  });

  test('tracesSampler is null by default', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(options.tracesSampler, isNull);
  });

  test('tracesSampleRate is null by default', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(options.tracesSampleRate, isNull);
  });

  test('isTracingEnabled is disabled', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(options.isTracingEnabled(), false);
  });

  test('isTracingEnabled is enabled by theres rate', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.tracesSampleRate = 1.0;

    expect(options.isTracingEnabled(), true);
  });

  test('isTracingEnabled is enabled by theres sampler', () {
    final options = SentryOptions(dsn: fakeDsn);

    double? sampler(SentrySamplingContext samplingContext) => 0.0;

    options.tracesSampler = sampler;

    expect(options.isTracingEnabled(), true);
  });
}
