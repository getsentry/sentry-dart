// ignore_for_file: invalid_use_of_internal_member
// The lint above is okay, because we're using another Sentry package

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/src/sentry_transformer.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_transport.dart';
import 'package:sentry/src/sentry_tracer.dart';

final requestUri = Uri.parse('https://example.com?foo=bar#baz');

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

      await sut.transformRequest(RequestOptions(path: requestUri.toString()));

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET https://example.com');
      expect(span.data['http.request.method'], 'GET');
      expect(span.data['url'], 'https://example.com');
      expect(span.data['http.query'], 'foo=bar');
      expect(span.data['http.fragment'], 'baz');
      expect(span.data['http.fragment'], 'baz');
      expect(span.origin, SentryTraceOrigins.autoHttpDioTransformer);
    });

    test('transformRequest finish span if errored request', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      try {
        await sut.transformRequest(RequestOptions(path: requestUri.toString()));
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET https://example.com');
      expect(span.data['http.request.method'], 'GET');
      expect(span.data['url'], 'https://example.com');
      expect(span.data['http.query'], 'foo=bar');
      expect(span.data['http.fragment'], 'baz');
      expect(span.finished, true);
      expect(span.origin, SentryTraceOrigins.autoHttpDioTransformer);
    });

    test('transformResponse creates span', () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.transformResponse(
        RequestOptions(path: requestUri.toString()),
        ResponseBody.fromString('', 200),
      );

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET https://example.com');
      expect(span.data['http.request.method'], 'GET');
      expect(span.data['url'], 'https://example.com');
      expect(span.data['http.query'], 'foo=bar');
      expect(span.data['http.fragment'], 'baz');
      expect(span.origin, SentryTraceOrigins.autoHttpDioTransformer);
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
          RequestOptions(path: requestUri.toString()),
          ResponseBody.fromString('', 200),
        );
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.context.operation, 'serialize.http.client');
      expect(span.context.description, 'GET https://example.com');
      expect(span.data['http.request.method'], 'GET');
      expect(span.data['url'], 'https://example.com');
      expect(span.data['http.query'], 'foo=bar');
      expect(span.data['http.fragment'], 'baz');
      expect(span.finished, true);
      expect(span.origin, SentryTraceOrigins.autoHttpDioTransformer);
    });
  });
}

class Fixture {
  final _options = defaultTestOptions();
  late Hub _hub;
  final transport = MockTransport();
  Fixture() {
    _options.transport = transport;
    _options.tracesSampleRate = 1.0;
    _hub = Hub(_options);
  }

  SentryTransformer getSut({bool throwException = false}) {
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
