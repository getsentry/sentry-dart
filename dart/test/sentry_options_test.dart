import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/noop_client.dart';
import 'package:sentry/src/version.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('$Client is NoOp', () {
    final options = defaultTestOptions();
    expect(NoOpClient(), options.httpClient);
  });

  test('$Client sets a custom client', () {
    final options = defaultTestOptions();

    final client = Client();
    options.httpClient = client;
    expect(client, options.httpClient);
  });

  test('maxBreadcrumbs is 100 by default', () {
    final options = defaultTestOptions();

    expect(100, options.maxBreadcrumbs);
  });

  test('maxBreadcrumbs sets custom maxBreadcrumbs', () {
    final options = defaultTestOptions();
    options.maxBreadcrumbs = 200;

    expect(200, options.maxBreadcrumbs);
  });

  test('SentryLogger sets a diagnostic logger', () {
    final options = defaultTestOptions();
    // ignore: deprecated_member_use_from_same_package
    expect(options.logger, noOpLogger);
    // ignore: deprecated_member_use_from_same_package
    options.logger = dartLogger;

    // ignore: deprecated_member_use_from_same_package
    expect(options.logger, isNot(noOpLogger));
  });

  test('tracesSampler is null by default', () {
    final options = defaultTestOptions();

    expect(options.tracesSampler, isNull);
  });

  test('tracesSampleRate is null by default', () {
    final options = defaultTestOptions();

    expect(options.tracesSampleRate, isNull);
  });

  test('isTracingEnabled is disabled', () {
    final options = defaultTestOptions();

    expect(options.isTracingEnabled(), false);
  });

  test('isTracingEnabled is enabled by theres rate', () {
    final options = defaultTestOptions();
    options.tracesSampleRate = 1.0;

    expect(options.isTracingEnabled(), true);
  });

  test('isTracingEnabled is enabled by theres sampler', () {
    final options = defaultTestOptions();

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
    final options = defaultTestOptions();

    expect(options.sentryClientName,
        '${sdkName(options.platformChecker.isWeb)}/$sdkVersion');
  });

  test('SentryOptions has default idleTimeout', () {
    final options = SentryOptions.empty();

    expect(options.idleTimeout?.inSeconds, Duration(seconds: 3).inSeconds);
  });

  test('when enableTracing is set to true tracing is considered enabled', () {
    final options = SentryOptions.empty();
    // ignore: deprecated_member_use_from_same_package
    options.enableTracing = true;

    expect(options.isTracingEnabled(), true);
  });

  test('when enableTracing is set to false tracing is considered disabled', () {
    final options = SentryOptions.empty();
    // ignore: deprecated_member_use_from_same_package
    options.enableTracing = false;
    options.tracesSampleRate = 1.0;
    options.tracesSampler = (_) {
      return 1.0;
    };

    expect(options.isTracingEnabled(), false);
  });

  test('Spotlight is disabled by default', () {
    final options = defaultTestOptions();

    expect(options.spotlight.enabled, false);
  });

  test('metrics are disabled by default', () {
    final options = defaultTestOptions();

    expect(options.enableMetrics, false);
  });

  test('enableExceptionTypeIdentification is enabled by default', () {
    final options = defaultTestOptions();

    expect(options.enableExceptionTypeIdentification, true);
  });

  test('default tags for metrics are enabled by default', () {
    final options = defaultTestOptions();
    options.enableMetrics = true;

    expect(options.enableDefaultTagsForMetrics, true);
  });

  test('default tags for metrics are disabled if metrics are disabled', () {
    final options = defaultTestOptions();
    options.enableMetrics = false;

    expect(options.enableDefaultTagsForMetrics, false);
  });

  test('default tags for metrics are enabled if metrics are enabled, too', () {
    final options = defaultTestOptions();
    options.enableMetrics = true;
    options.enableDefaultTagsForMetrics = true;

    expect(options.enableDefaultTagsForMetrics, true);
  });

  test('span local metric aggregation is enabled by default', () {
    final options = defaultTestOptions();
    options.enableMetrics = true;

    expect(options.enableSpanLocalMetricAggregation, true);
  });

  test('span local metric aggregation is disabled if metrics are disabled', () {
    final options = defaultTestOptions();
    options.enableMetrics = false;

    expect(options.enableSpanLocalMetricAggregation, false);
  });

  test('span local metric aggregation is enabled if metrics are enabled, too',
      () {
    final options = defaultTestOptions();
    options.enableMetrics = true;
    options.enableSpanLocalMetricAggregation = true;

    expect(options.enableSpanLocalMetricAggregation, true);
  });

  test('enablePureDartSymbolication is enabled by default', () {
    final options = defaultTestOptions();

    expect(options.enableDartSymbolication, true);
  });
}
