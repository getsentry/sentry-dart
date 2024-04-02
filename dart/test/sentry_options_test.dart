import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_client.dart';
import 'package:sentry/src/version.dart';
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
    // ignore: deprecated_member_use_from_same_package
    expect(options.logger, noOpLogger);
    // ignore: deprecated_member_use_from_same_package
    options.logger = dartLogger;

    // ignore: deprecated_member_use_from_same_package
    expect(options.logger, isNot(noOpLogger));
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

  test('SentryOptions empty inits the late var', () {
    final options = SentryOptions.empty();
    options.sdk.addPackage('test', '1.2.3');

    expect(
        options.sdk.packages
            .where((element) =>
                element.name == 'test' && element.version == '1.2.3')
            .isNotEmpty,
        true);
  });

  test('SentryOptions has all targets by default', () {
    final options = SentryOptions.empty();

    expect(options.tracePropagationTargets, ['.*']);
  });

  test('SentryOptions has sentryClientName set', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(options.sentryClientName,
        '${sdkName(options.platformChecker.isWeb)}/$sdkVersion');
  });

  test('SentryOptions has default idleTimeout', () {
    final options = SentryOptions.empty();

    expect(options.idleTimeout?.inSeconds, Duration(seconds: 3).inSeconds);
  });

  test('when enableTracing is set to true tracing is considered enabled', () {
    final options = SentryOptions.empty();
    options.enableTracing = true;

    expect(options.isTracingEnabled(), true);
  });

  test('when enableTracing is set to false tracing is considered disabled', () {
    final options = SentryOptions.empty();
    options.enableTracing = false;
    options.tracesSampleRate = 1.0;
    options.tracesSampler = (_) {
      return 1.0;
    };

    expect(options.isTracingEnabled(), false);
  });

  test('Spotlight is disabled by default', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(options.spotlight.enabled, false);
  });

  test('metrics are disabled by default', () {
    final options = SentryOptions(dsn: fakeDsn);

    expect(options.enableMetrics, false);
  });

  test('default tags for metrics are enabled by default', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.enableMetrics = true;

    expect(options.enableDefaultTagsForMetrics, true);
  });

  test('default tags for metrics are disabled if metrics are disabled', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.enableMetrics = false;

    expect(options.enableDefaultTagsForMetrics, false);
  });

  test('default tags for metrics are enabled if metrics are enabled, too', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.enableMetrics = true;
    options.enableDefaultTagsForMetrics = true;

    expect(options.enableDefaultTagsForMetrics, true);
  });

  test('span local metric aggregation is enabled by default', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.enableMetrics = true;

    expect(options.enableSpanLocalMetricAggregation, true);
  });

  test('span local metric aggregation is disabled if metrics are disabled', () {
    final options = SentryOptions(dsn: fakeDsn);
    options.enableMetrics = false;

    expect(options.enableSpanLocalMetricAggregation, false);
  });

  test('span local metric aggregation is enabled if metrics are enabled, too',
      () {
    final options = SentryOptions(dsn: fakeDsn);
    options.enableMetrics = true;
    options.enableSpanLocalMetricAggregation = true;

    expect(options.enableSpanLocalMetricAggregation, true);
  });
}
