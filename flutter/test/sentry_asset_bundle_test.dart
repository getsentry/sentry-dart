// ignore_for_file: invalid_use_of_internal_member
// The lint above is okay, because we're using another Sentry package
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/src/sentry_tracer.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';

const _testFileName = 'resources/test.txt';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group(SentryAssetBundle, () {
    test('load: creates a span if transaction is bound to scope', () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.load(_testFileName);

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'SentryAssetBundle.load');
      expect(span.context.description, _testFileName);
    });

    test('load: end span with error if exception is thrown', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      try {
        await sut.load(_testFileName);
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.finished, true);
      expect(span.context.operation, 'SentryAssetBundle.load');
      expect(span.context.description, _testFileName);
    });

    test(
      'loadStructuredData: creates two spans if transaction is bound to scope',
      () async {
        final sut = fixture.getSut();
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        await sut.loadStructuredData<String>(
          _testFileName,
          (value) async => value.toString(),
        );

        await tr.finish();

        final tracer = (tr as SentryTracer);

        expect(tracer.children.length, 2);

        final outerSpan = tracer.children.first;
        expect(outerSpan.status, SpanStatus.internalError());
        expect(outerSpan.finished, true);
        expect(
          outerSpan.context.operation,
          'SentryAssetBundle.loadStructuredData',
        );
        expect(outerSpan.context.description, _testFileName);

        final innerSpan = tracer.children[1];
        expect(innerSpan.status, SpanStatus.internalError());
        expect(innerSpan.finished, true);
        expect(
          innerSpan.context.operation,
          'SentryAssetBundle.parseStructuredData',
        );
        expect(innerSpan.context.description, _testFileName);
      },
    );

    test(
      'loadStructuredData: end span with error if exception is thrown while loading',
      () async {
        final sut = fixture.getSut(throwException: true);
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        try {
          await sut.loadStructuredData<String>(
            _testFileName,
            (value) async => value.toString(),
          );
        } catch (_) {}

        await tr.finish();

        final tracer = (tr as SentryTracer);

        expect(tracer.children.length, 2);

        final outerSpan = tracer.children.first;
        expect(outerSpan.status, SpanStatus.internalError());
        expect(outerSpan.finished, true);
        expect(
          outerSpan.context.operation,
          'SentryAssetBundle.loadStructuredData',
        );
        expect(outerSpan.context.description, _testFileName);

        final innerSpan = tracer.children[1];
        expect(innerSpan.status, SpanStatus.internalError());
        expect(innerSpan.finished, true);
        expect(
          innerSpan.context.operation,
          'SentryAssetBundle.parseStructuredData',
        );
        expect(innerSpan.context.description, _testFileName);
      },
    );

    test(
      'loadStructuredData: end span with error if exception is thrown while parsing',
      () async {
        final sut = fixture.getSut();
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        try {
          await sut.loadStructuredData<String>(
            _testFileName,
            (value) => throw Exception(),
          );
        } catch (_) {}

        await tr.finish();

        final tracer = (tr as SentryTracer);

        expect(tracer.children.length, 2);

        final outerSpan = tracer.children.first;
        expect(outerSpan.status, SpanStatus.ok());
        expect(outerSpan.finished, true);
        expect(
          outerSpan.context.operation,
          'SentryAssetBundle.loadStructuredData',
        );
        expect(outerSpan.context.description, _testFileName);

        final innerSpan = tracer.children[1];
        expect(innerSpan.status, SpanStatus.ok());
        expect(innerSpan.finished, true);
        expect(
          innerSpan.context.operation,
          'SentryAssetBundle.parseStructuredData',
        );
        expect(innerSpan.context.description, _testFileName);
      },
    );
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

  SentryAssetBundle getSut({
    bool throwException = false,
  }) {
    return SentryAssetBundle(
      hub: _hub,
      bundle: TestAssetBundle(throwException),
    );
  }
}

class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle(this.throwException);

  final bool throwException;

  @override
  Future<ByteData> load(String key) async {
    if (throwException) {
      throw FlutterError('"$key" could not be found in assets');
    }
    if (key == _testFileName) {
      return ByteData.view(
          Uint8List.fromList(utf8.encode('Hello World!')).buffer);
    }
    return ByteData(0);
  }
}
