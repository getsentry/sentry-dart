import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_sentry_client.dart';

void main() {
  group('$containsTargetOrMatchesRegExp', () {
    final origins = ['localhost', '^(http|https)://api\\..*\$'];

    test('origins contains the url when it contains one of the defined origins',
        () {
      expect(
          containsTargetOrMatchesRegExp(origins, 'http://localhost:8080/foo'),
          isTrue);
      expect(
          containsTargetOrMatchesRegExp(
              origins, 'http://xxx.localhost:8080/foo'),
          isTrue);
    });

    test('origins contain the url when it matches regex', () {
      expect(
          containsTargetOrMatchesRegExp(origins, 'http://api.foo.bar:8080/foo'),
          isTrue);
      expect(
          containsTargetOrMatchesRegExp(
              origins, 'https://api.foo.bar:8080/foo'),
          isTrue);
      expect(
          containsTargetOrMatchesRegExp(
              origins, 'http://api.localhost:8080/foo'),
          isTrue);
      expect(
          containsTargetOrMatchesRegExp(origins, 'ftp://api.foo.bar:8080/foo'),
          isFalse);
    });

    test('invalid regex do not throw', () {
      expect(
          containsTargetOrMatchesRegExp(
              ['AABB???', '^(http|https)://api\\..*\$'],
              'http://api.foo.bar:8080/foo'),
          isTrue);
    });

    test('when no origins are defined, returns false for every url', () {
      expect(containsTargetOrMatchesRegExp([], 'api.foo.com'), isFalse);
    });
  });

  group('$addSentryTraceHeader', () {
    final fixture = Fixture();

    test('adds sentry trace header', () {
      final headers = <String, String>{};
      final sut = fixture.getSut();
      final sentryHeader = sut.toSentryTrace();

      addSentryTraceHeader(sut, headers);

      expect(headers[sentryHeader.name], sentryHeader.value);
    });
  });

  group('$addBaggageHeader', () {
    final fixture = Fixture();

    test('adds baggage header', () {
      final headers = <String, String>{};
      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      addBaggageHeader(sut, headers);

      expect(headers[baggage!.name], baggage.value);
    });

    test('appends baggage header', () {
      final headers = <String, String>{};
      final oldValue = 'other-vendor-value-1=foo';
      headers['baggage'] = oldValue;

      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      final newValue = '$oldValue,${baggage!.value}';

      addBaggageHeader(sut, headers);

      expect(headers[baggage.name], newValue);
    });

    test('overwrites duplicate key values', () {
      final headers = <String, String>{};
      final oldValue =
          'other-vendor-value=foo,sentry-trace_id=${SentryId.newId()},sentry-public_key=oldPublicKey,sentry-release=oldRelease,sentry-environment=oldEnvironment,sentry-user_id=oldUserId,sentry-user_segment=oldUserSegment,sentry-transaction=oldTransaction,sentry-sample_rate=0.5';

      headers['baggage'] = oldValue;

      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      addBaggageHeader(sut, headers);

      expect(headers[baggage!.name],
          'other-vendor-value=foo,sentry-trace_id=${sut.context.traceId},sentry-public_key=abc,sentry-release=release,sentry-environment=environment,sentry-user_segment=segment,sentry-transaction=name,sentry-sample_rate=1');
    });
  });

  group('$isValidSampleRate', () {
    test('returns false if null sampleRate', () {
      expect(isValidSampleRate(null), false);
    });

    test('returns true if 1', () {
      expect(isValidSampleRate(1.0), true);
    });

    test('returns true if 0', () {
      expect(isValidSampleRate(0.0), true);
    });

    test('returns false if below the range', () {
      expect(isValidSampleRate(-0.01), false);
    });

    test('returns false if above the range', () {
      expect(isValidSampleRate(1.01), false);
    });

    test('returns false if NaN', () {
      expect(isValidSampleRate(double.nan), false);
    });
  });
}

class Fixture {
  final _context = SentryTransactionContext(
    'name',
    'op',
    transactionNameSource: SentryTransactionNameSource.custom,
    samplingDecision: SentryTracesSamplingDecision(
      true,
      sampleRate: 1.0,
    ),
  );

  final _options = SentryOptions(dsn: fakeDsn)
    ..release = 'release'
    ..environment = 'environment';

  late Hub _hub;

  final _client = MockSentryClient();

  final _user = SentryUser(
    id: 'id',
    segment: 'segment',
  );

  SentryTracer getSut() {
    _hub = Hub(_options);
    _hub.configureScope((scope) => scope.setUser(_user));

    _hub.bindClient(_client);
    return SentryTracer(_context, _hub);
  }
}
