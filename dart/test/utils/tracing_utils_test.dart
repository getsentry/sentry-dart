import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_sentry_client.dart';

void main() {
  group('$containsTracePropagationTarget', () {
    final origins = ['localhost', '^(http|https)://api\\..*\$'];

    test('origins contain the url when it contains one of the defined origins',
        () {
      expect(
          containsTracePropagationTarget(origins, 'http://localhost:8080/foo'),
          isTrue);
      expect(
          containsTracePropagationTarget(
              origins, 'http://xxx.localhost:8080/foo'),
          isTrue);
    });

    test('origins contain the url when it matches regex', () {
      expect(
          containsTracePropagationTarget(
              origins, 'http://api.foo.bar:8080/foo'),
          isTrue);
      expect(
          containsTracePropagationTarget(
              origins, 'https://api.foo.bar:8080/foo'),
          isTrue);
      expect(
          containsTracePropagationTarget(
              origins, 'http://api.localhost:8080/foo'),
          isTrue);
      expect(
          containsTracePropagationTarget(origins, 'ftp://api.foo.bar:8080/foo'),
          false);
    });

    test('when no origins are defined, returns true for every url', () {
      expect(containsTracePropagationTarget([], 'api.foo.com'), isTrue);
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
