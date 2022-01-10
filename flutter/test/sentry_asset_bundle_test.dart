// ignore_for_file: invalid_use_of_internal_member
// The lint above is okay, because we're using another Sentry package
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
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
      expect(span.context.operation, 'file.read');
      expect(
          span.context.description, 'AssetBundle.load(key=resources/test.txt)');
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
      expect(span.context.operation, 'file.read');
      expect(
          span.context.description, 'AssetBundle.load(key=resources/test.txt)');
    });

    test('loadString: creates a span if transaction is bound to scope',
        () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await sut.loadString(_testFileName);

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.context.description,
          'AssetBundle.loadString(key=resources/test.txt, cache=true)');
    });

    test('loadString: end span with error if exception is thrown', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction(
        'name',
        'op',
        bindToScope: true,
      );

      await expectLater(
          sut.loadString(_testFileName), throwsA(isA<Exception>()));

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.context.description,
          'AssetBundle.loadString(key=resources/test.txt, cache=true)');
    });

    test(
      'loadStructuredData: does not create any spans and just forwords the call to the underlying assetbundle',
      () async {
        final sut = fixture.getSut();
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        final data = await sut.loadStructuredData<String>(
          _testFileName,
          (value) async => value.toString(),
        );
        expect(data, 'Hello World!');

        await tr.finish();

        final tracer = (tr as SentryTracer);

        expect(tracer.children.length, 0);
      },
    );

    test(
      'evict call gets forwarded',
      () {
        final sut = fixture.getSut();

        sut.evict(_testFileName);

        expect(fixture.assetBundle.evictKey, _testFileName);
      },
    );
  });
}

class Fixture {
  final _options = SentryOptions(dsn: fakeDsn);
  late Hub _hub;
  final transport = MockTransport();
  final assetBundle = TestAssetBundle();
  Fixture() {
    _options.transport = transport;
    _options.tracesSampleRate = 1.0;
    _hub = Hub(_options);
  }

  SentryAssetBundle getSut({
    bool throwException = false,
  }) {
    when(transport.send(any)).thenAnswer((_) async => SentryId.newId());
    return SentryAssetBundle(
      hub: _hub,
      bundle: assetBundle..throwException = throwException,
    );
  }
}

class TestAssetBundle extends CachingAssetBundle {
  bool throwException = false;
  String? evictKey;

  @override
  Future<ByteData> load(String key) async {
    if (throwException) {
      throw Exception('"$key" could not be found in assets');
    }
    if (key == _testFileName) {
      return ByteData.view(
          Uint8List.fromList(utf8.encode('Hello World!')).buffer);
    }
    return ByteData(0);
  }

  @override
  void evict(String key) {
    super.evict(key);
    evictKey = key;
  }
}
