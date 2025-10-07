import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks/mock_sentry_client.dart';
import '../test_utils.dart';

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

  group('$addSentryTraceHeaderFromSpan', () {
    final fixture = Fixture();

    test('adds sentry trace header from span', () {
      final headers = <String, String>{};
      final sut = fixture.getSut();
      final sentryHeader = sut.toSentryTrace();

      addSentryTraceHeaderFromSpan(sut, headers);

      expect(headers[sentryHeader.name], sentryHeader.value);
    });

    test('adds sentry trace header', () {
      final headers = <String, String>{};
      final sut = fixture.getSut();
      final sentryHeader = sut.toSentryTrace();

      addSentryTraceHeader(sentryHeader, headers);

      expect(headers[sentryHeader.name], sentryHeader.value);
    });
  });

  group('W3C traceparent header', () {
    final fixture = Fixture();
    final headerName = 'traceparent';

    test('converts SentryTraceHeader to W3C format correctly', () {
      final sut = fixture.getSut();
      final sentryHeader = sut.toSentryTrace();

      final w3cHeader = formatAsW3CHeader(sentryHeader);

      expect(w3cHeader,
          '00-${fixture._context.traceId}-${fixture._context.spanId}-01');
    });

    test('added when given a span', () {
      final headers = <String, dynamic>{};
      final sut = fixture.getSut();

      addW3CHeaderFromSpan(sut, headers);

      expect(headers[headerName],
          '00-${fixture._context.traceId}-${fixture._context.spanId}-01');
    });

    test('added when given a scope', () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      final scope = hub.scope;

      addW3CHeaderFromScope(scope, headers);

      final headerValue = headers[headerName] as String;
      final parts = headerValue.split('-');

      expect(parts.length, 4);
      expect(parts[0], '00');
      expect(parts[1], scope.propagationContext.traceId.toString());
      expect(parts[2], hasLength(16)); // just check length since it's random
      expect(parts[3], '00');
    });
  });

  group('$addBaggageHeader', () {
    final fixture = Fixture();

    test('adds baggage header', () {
      final headers = <String, String>{};
      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      addBaggageHeader(sut.toBaggageHeader()!, headers);

      expect(headers[baggage!.name], baggage.value);
    });

    test('adds baggage header from span', () {
      final headers = <String, String>{};
      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      addBaggageHeaderFromSpan(sut, headers);

      expect(headers[baggage!.name], baggage.value);
    });

    test('appends baggage header from span', () {
      final headers = <String, String>{};
      final oldValue = 'other-vendor-value-1=foo';
      headers['baggage'] = oldValue;

      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      final newValue = '$oldValue,${baggage!.value}';

      addBaggageHeaderFromSpan(sut, headers);

      expect(headers[baggage.name], newValue);
    });

    test('overwrites duplicate key values', () {
      final headers = <String, String>{};
      final oldValue =
          'other-vendor-value=foo,sentry-trace_id=${SentryId.newId()},sentry-public_key=oldPublicKey,sentry-release=oldRelease,sentry-environment=oldEnvironment,sentry-user_id=oldUserId,sentry-transaction=oldTransaction,sentry-sample_rate=0.5';

      headers['baggage'] = oldValue;

      final sut = fixture.getSut();
      final baggage = sut.toBaggageHeader();

      addBaggageHeaderFromSpan(sut, headers);

      expect(headers[baggage!.name],
          'other-vendor-value=foo,sentry-trace_id=${sut.context.traceId},sentry-public_key=public,sentry-release=release,sentry-environment=environment,sentry-transaction=name,sentry-sample_rate=1,sentry-sampled=true');
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

  group('$generateSentryTraceHeader', () {
    test('generates header with new ids when not provided', () {
      final header = generateSentryTraceHeader();

      expect(header.traceId, isNotNull);
      expect(header.spanId, isNotNull);
      expect(header.sampled, isNull);
    });

    test('generates header with provided traceId', () {
      final traceId = SentryId.newId();
      final header = generateSentryTraceHeader(traceId: traceId);

      expect(header.traceId, traceId);
      expect(header.spanId, isNotNull);
      expect(header.sampled, isNull);
    });

    test('generates header with provided spanId', () {
      final spanId = SpanId.newId();
      final header = generateSentryTraceHeader(spanId: spanId);

      expect(header.traceId, isNotNull);
      expect(header.spanId, spanId);
      expect(header.sampled, isNull);
    });

    test('generates header with provided sampled decision', () {
      final header = generateSentryTraceHeader(sampled: true);

      expect(header.traceId, isNotNull);
      expect(header.spanId, isNotNull);
      expect(header.sampled, true);
    });

    test('generates header with all parameters provided', () {
      final traceId = SentryId.newId();
      final spanId = SpanId.newId();
      final header = generateSentryTraceHeader(
        traceId: traceId,
        spanId: spanId,
        sampled: false,
      );

      expect(header.traceId, traceId);
      expect(header.spanId, spanId);
      expect(header.sampled, false);
    });
  });

  group(addTracingHeadersToHttpHeader, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
        'adds W3C traceparent header from span when propagateTraceparent is true',
        () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      final span = fixture.getSut();
      hub.options.propagateTraceparent = true;

      addTracingHeadersToHttpHeader(headers, hub, span: span);

      expect(headers['traceparent'],
          '00-${fixture._context.traceId}-${fixture._context.spanId}-01');
    });

    test(
        'does not add W3C traceparent header from span when propagateTraceparent is false',
        () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      // propagateTraceparent is false by default

      addTracingHeadersToHttpHeader(headers, hub);

      expect(headers['traceparent'], isNull);
    });

    test(
        'adds W3C traceparent header from scope when propagateTraceparent is true',
        () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      hub.options.propagateTraceparent = true;

      addTracingHeadersToHttpHeader(headers, hub);

      final headerValue = headers['traceparent'] as String;
      final parts = headerValue.split('-');

      expect(parts.length, 4);
      expect(parts[0], '00');
      expect(parts[1], hub.scope.propagationContext.traceId.toString());
      expect(parts[2], hasLength(16)); // just check length since it's random
      expect(parts[3], '00'); // not sampled for scope context
    });

    test(
        'does not add W3C traceparent header from scope when propagateTraceparent is false',
        () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      // propagateTraceparent is false by default

      addTracingHeadersToHttpHeader(headers, hub);

      expect(headers['traceparent'], isNull);
    });

    test('adds headers from span when span is provided', () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      final span = fixture.getSut();

      addTracingHeadersToHttpHeader(headers, hub, span: span);

      final traceHeader =
          SentryTraceHeader.fromTraceHeader(headers['sentry-trace']);
      expect(traceHeader.traceId, span.context.traceId);
      expect(traceHeader.spanId, span.context.spanId);
      expect(traceHeader.sampled, span.samplingDecision?.sampled);
      expect(headers['baggage'], isNotNull);
    });

    test('adds headers from scope when span is null', () {
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      hub.configureScope((scope) {
        scope.propagationContext.baggage = SentryBaggage({'test': 'value'});
      });

      addTracingHeadersToHttpHeader(headers, hub);

      final traceHeader =
          SentryTraceHeader.fromTraceHeader(headers['sentry-trace']);
      expect(traceHeader.traceId, hub.scope.propagationContext.traceId);
      expect(headers['baggage'], contains('test=value'));
    });
  });

  group('$addSentryTraceHeaderFromScope', () {
    test('adds sentry trace header from scope propagation context', () {
      final fixture = Fixture();
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      final scope = hub.scope;

      addSentryTraceHeaderFromScope(scope, headers);

      final traceHeader =
          SentryTraceHeader.fromTraceHeader(headers['sentry-trace']);
      expect(traceHeader.traceId, scope.propagationContext.traceId);
    });
  });

  group('$addBaggageHeaderFromScope', () {
    test('adds baggage header from scope when baggage exists', () {
      final fixture = Fixture();
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      final scope = hub.scope;
      scope.propagationContext.baggage = SentryBaggage({
        'sentry-trace_id': scope.propagationContext.traceId.toString(),
        'sentry-public_key': 'public',
        'custom': 'value',
      });

      addBaggageHeaderFromScope(scope, headers);

      expect(headers['baggage'], isNotNull);
      expect(headers['baggage'], contains('custom=value'));
      expect(headers['baggage'], contains('sentry-public_key=public'));
    });

    test('does not add baggage header when baggage is null', () {
      final fixture = Fixture();
      final headers = <String, dynamic>{};
      final hub = fixture._hub;
      final scope = hub.scope;
      scope.propagationContext.baggage = null;

      addBaggageHeaderFromScope(scope, headers);

      expect(headers['baggage'], isNull);
    });
  });

  group('$isValidSampleRand', () {
    test('returns false if null sampleRand', () {
      expect(isValidSampleRand(null), false);
    });

    test('returns true if 0', () {
      expect(isValidSampleRand(0.0), true);
    });

    test('returns true if 0.5', () {
      expect(isValidSampleRand(0.5), true);
    });

    test('returns true if 0.999', () {
      expect(isValidSampleRand(0.999), true);
    });

    test('returns false if 1.0', () {
      expect(isValidSampleRand(1.0), false);
    });

    test('returns false if below the range', () {
      expect(isValidSampleRand(-0.01), false);
    });

    test('returns false if above the range', () {
      expect(isValidSampleRand(1.01), false);
    });

    test('returns false if NaN', () {
      expect(isValidSampleRand(double.nan), false);
    });
  });
}

class Fixture {
  Fixture() {
    _hub = Hub(_options);
    _hub.configureScope((scope) => scope.setUser(_user));

    _hub.bindClient(_client);
  }

  final _context = SentryTransactionContext(
    'name',
    'op',
    transactionNameSource: SentryTransactionNameSource.custom,
    samplingDecision: SentryTracesSamplingDecision(
      true,
      sampleRate: 1.0,
    ),
  );

  final _options = defaultTestOptions()
    ..release = 'release'
    ..environment = 'environment';

  late Hub _hub;

  final _client = MockSentryClient();

  final _user = SentryUser(
    id: 'id',
  );

  SentryTracer getSut() {
    return SentryTracer(_context, _hub);
  }
}
