// ignore_for_file: invalid_use_of_internal_member
// The lint above is okay, because we're using another Sentry package

import 'package:diox/diox.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_diox/src/sentry_transformer.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_transport.dart';
import 'package:sentry/src/sentry_tracer.dart';

void main() {
  group(SentryTransformer, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });
    test('transformRequest creates span', () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.transformRequest(RequestOptions(path: 'foo'));

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET foo');
    });

    test('transformRequest finish span if errored request', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      try {
        await sut.transformRequest(RequestOptions(path: 'foo'));
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET foo');
      expect(span.finished, true);
    });

    test('transformResponse creates span', () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.transformResponse(
        RequestOptions(path: 'foo'),
        ResponseBody.fromString('', 200),
      );

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET foo');
    });
    test('transformResponse finish span if errored request', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      try {
        await sut.transformResponse(
          RequestOptions(path: 'foo'),
          ResponseBody.fromString('', 200),
        );
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET foo');
      expect(span.finished, true);
    });
  });
}

class Fixture {
  final _options = SentryOptions(dsn: fakeDsn);
  late Hub _hub;
  final transport = MockTransport();
  Fixture() {
    _options.transport = transport;
    _options.tracesSampleRate = 1.0;
    _hub = Hub(_options);
  }

  Transformer getSut({bool throwException = false}) {
    return SentryTransformer(
      transformer: MockTransformer(throwException),
      hub: _hub,
    );
  }
}

class MockTransformer implements Transformer {
  MockTransformer(this.throwException);

  final bool throwException;

  @override
  Future<String> transformRequest(RequestOptions options) async {
    if (throwException) {
      throw Exception('Exception');
    }
    return '';
  }

  @override
  // ignore: strict_raw_type
  Future transformResponse(
    RequestOptions options,
    ResponseBody response,
  ) async {
    if (throwException) {
      throw Exception('Exception');
    }
    return '';
  }
}
