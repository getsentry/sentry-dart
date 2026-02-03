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

  test('SdkLogger sets a diagnostic logger', () {
    final options = defaultTestOptions();
    expect(options.log, noOpLog);
    options.debug = true;

    expect(options.log, isNot(noOpLog));
  });

  test('setting debug correctly sets logger', () {
    final options = defaultTestOptions();
    expect(options.log, noOpLog);
    expect(options.diagnosticLog, isNull);
    options.debug = true;
    expect(options.log, isNot(options.debugLog));
    expect(options.diagnosticLog!.logger, options.debugLog);
    expect(options.log, options.diagnosticLog!.log);

    options.debug = false;
    expect(options.log, isNot(noOpLog));
    expect(options.diagnosticLog!.logger, noOpLog);
    expect(options.log, options.diagnosticLog!.log);

    options.debug = true;
    expect(options.log, isNot(options.debugLog));
    expect(options.diagnosticLog!.logger, options.debugLog);
    expect(options.log, options.diagnosticLog!.log);
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
        '${sdkName(options.platform.isWeb)}/$sdkVersion');
  });

  test('SentryOptions has default idleTimeout', () {
    final options = SentryOptions.empty();

    expect(options.idleTimeout?.inSeconds, Duration(seconds: 3).inSeconds);
  });

  test('Spotlight is disabled by default', () {
    final options = defaultTestOptions();

    expect(options.spotlight.enabled, false);
  });

  test('enableExceptionTypeIdentification is enabled by default', () {
    final options = defaultTestOptions();

    expect(options.enableExceptionTypeIdentification, true);
  });

  test('enablePureDartSymbolication is enabled by default', () {
    final options = defaultTestOptions();

    expect(options.enableDartSymbolication, true);
  });

  test('diagnosticLevel is warning by default', () {
    final options = defaultTestOptions();

    expect(options.diagnosticLevel, SentryLevel.warning);
  });

  test('parsedDsn is correctly parsed and cached', () {
    final options = defaultTestOptions();

    // Access parsedDsn for the first time
    final parsedDsn1 = options.parsedDsn;

    // Access parsedDsn again
    final parsedDsn2 = options.parsedDsn;

    // Should return the same instance since it's cached
    expect(identical(parsedDsn1, parsedDsn2), isTrue);

    // Verify the parsed DSN fields
    final manuallyParsedDsn = Dsn.parse(options.dsn!);
    expect(parsedDsn1.publicKey, manuallyParsedDsn.publicKey);
    expect(parsedDsn1.postUri, manuallyParsedDsn.postUri);
    expect(parsedDsn1.secretKey, manuallyParsedDsn.secretKey);
    expect(parsedDsn1.projectId, manuallyParsedDsn.projectId);
    expect(parsedDsn1.uri, manuallyParsedDsn.uri);
  });

  test('parsedDsn throws when DSN is null', () {
    final options = defaultTestOptions()..dsn = null;

    expect(() => options.parsedDsn, throwsA(isA<StateError>()));
  });

  test('parsedDsn throws when DSN is empty', () {
    final options = defaultTestOptions()..dsn = '';

    expect(() => options.parsedDsn, throwsA(isA<StateError>()));
  });

  test('enableMetrics is true by default', () {
    final options = defaultTestOptions();

    expect(options.enableMetrics, true);
  });
}
