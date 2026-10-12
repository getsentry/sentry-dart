// ignore_for_file: invalid_use_of_internal_member
// The lint above is okay, because we're using another Sentry package
import 'dart:async';
import 'dart:convert';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';
// ignore: unnecessary_import
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/src/telemetry/span/instrumentation/span_factory_integration.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/src/telemetry/span/transaction/sentry_tracer.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const _testFileName = 'resources/test.txt';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$SentryAssetBundle', () {
    group('with streaming lifecycle', () {
      late StreamingFixture fixture;

      setUp(() {
        fixture = StreamingFixture();
      });

      tearDown(() async {
        await fixture.hub.close();
      });

      test('records asset load as a child of the active span', () async {
        final sut = fixture.getSut();
        late SentrySpanV2 parent;

        await fixture.hub.startSpan('parent', (span) async {
          parent = span;
          final data = await sut.load(_testFileName);
          expect(data.lengthInBytes, 12);
        });

        final child = fixture.findSpanByOperation('file.read');
        expect(child, isNotNull);
        expect(fixture.processor.addedSpans, contains(same(child)));
        expect(child!.parentSpan, same(parent));
        expect(child.name, 'AssetBundle.load: test.txt');
        expect(child.isEnded, isTrue);
        expect(child.status, SentrySpanStatusV2.ok);
        expect(child.attributes['file.path']?.value, 'resources/test.txt');
        expect(child.attributes['file.size']?.value, 12);
        expect(
          child.attributes['sentry.origin']?.value,
          'auto.file.asset_bundle',
        );
      });
      test('records string loads and preserves the cache attribute', () async {
        final sut = fixture.getSut();

        await fixture.hub.startSpan('parent', (_) async {
          expect(
            await sut.loadString(_testFileName, cache: false),
            'Hello World!',
          );
        });

        final child = fixture.findSpanByOperation('file.read');
        expect(child, isNotNull);
        expect(child!.name, 'AssetBundle.loadString: test.txt');
        expect(child.attributes['from-cache']?.value, isFalse);
        expect(child.isEnded, isTrue);
      });

      test('records buffer loads with their size', () async {
        final sut = fixture.getSut();

        await fixture.hub.startSpan('parent', (_) async {
          final buffer = await sut.loadBuffer(_testFileName);
          expect(buffer.length, 12);
          buffer.dispose();
        });

        final child = fixture.findSpanByOperation('file.read');
        expect(child, isNotNull);
        expect(child!.name, 'AssetBundle.loadBuffer: test.txt');
        expect(child.attributes['file.size']?.value, 12);
        expect(child.isEnded, isTrue);
      });

      for (final binary in [false, true]) {
        final method = binary
            ? 'loadStructuredBinaryData'
            : 'loadStructuredData';

        Future<int> loadStructured(SentryAssetBundle bundle, {Object? error}) {
          if (binary) {
            return bundle.loadStructuredBinaryData<int>(_testFileName, (data) {
              if (error != null) throw error;
              return data.lengthInBytes;
            });
          }
          return bundle.loadStructuredData<int>(_testFileName, (data) async {
            if (error != null) throw error;
            return data.length;
          });
        }

        test('records $method and parsing under the active span', () async {
          final sut = fixture.getSut();
          late SentrySpanV2 parent;

          await fixture.hub.startSpan('parent', (span) async {
            parent = span;
            expect(await loadStructured(sut), 12);
          });

          final load = fixture.findSpanByOperation('file.read');
          final parser = fixture.findSpanByOperation('serialize.file.read');
          expect(load, isNotNull);
          expect(parser, isNotNull);
          expect(load!.name, 'AssetBundle.$method<int>: test.txt');
          expect(parser!.name, 'parsing "resources/test.txt" to "int"');
          for (final span in [load, parser]) {
            expect(span.parentSpan, same(parent));
            expect(span.isEnded, isTrue);
            expect(span.status, SentrySpanStatusV2.ok);
            expect(
              span.attributes['sentry.origin']?.value,
              'auto.file.asset_bundle',
            );
          }
        });

        test(
          'marks $method load and parser spans as errors when parsing fails',
          () async {
            final sut = fixture.getSut();
            final error = StateError('parsing failed');

            await fixture.hub.startSpan('parent', (_) async {
              await expectLater(
                loadStructured(sut, error: error),
                throwsA(same(error)),
              );
            });

            final load = fixture.findSpanByOperation('file.read');
            final parser = fixture.findSpanByOperation('serialize.file.read');
            expect(load, isNotNull);
            expect(parser, isNotNull);
            for (final span in [load!, parser!]) {
              expect(span.isEnded, isTrue);
              expect(span.status, SentrySpanStatusV2.error);
            }
          },
        );

        test(
          'skips $method spans when structured data tracing is disabled',
          () async {
            final sut = fixture.getSut(structuredDataTracing: false);

            await fixture.hub.startSpan('parent', (_) async {
              expect(await loadStructured(sut), 12);
            });

            expect(fixture.findSpanByOperation('file.read'), isNull);
            expect(fixture.findSpanByOperation('serialize.file.read'), isNull);
          },
        );
      }

      test('ends the load span with error status when loading fails', () async {
        final sut = fixture.getSut();
        fixture.assetBundle.throwException = true;

        await fixture.hub.startSpan('parent', (_) async {
          await expectLater(sut.load(_testFileName), throwsA(isA<Exception>()));
        });

        final child = fixture.findSpanByOperation('file.read');
        expect(child, isNotNull);
        expect(child!.isEnded, isTrue);
        expect(child.status, SentrySpanStatusV2.error);
      });

      test(
        'loads assets without creating a span when no parent is active',
        () async {
          final data = await fixture.getSut().load(_testFileName);

          expect(data.lengthInBytes, 12);
          expect(fixture.spans, isEmpty);
        },
      );

      test(
        'loads assets without creating a span when the parent is unsampled',
        () async {
          fixture.options.tracesSampleRate = 0.0;
          final sut = fixture.getSut();

          await fixture.hub.startSpan('parent', (_) async {
            expect((await sut.load(_testFileName)).lengthInBytes, 12);
          });

          expect(fixture.spans, isEmpty);
        },
      );
    });

    test('empty key does not throw', () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      await sut.load('');

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.data['file.path'], '');
      expect(span.data['file.size'], 0);
      expect(span.context.description, 'AssetBundle.load: ');
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test('load - creates a span if transaction is bound to scope', () async {
      final sut = fixture.getSut();
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      await sut.load(_testFileName);

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.data['file.path'], 'resources/test.txt');
      expect(span.data['file.size'], 12);
      expect(span.context.description, 'AssetBundle.load: test.txt');
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test('load: end span with error if exception is thrown', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      try {
        await sut.load(_testFileName);
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.context.description, 'AssetBundle.load: test.txt');
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test(
      'loadString - creates a span if transaction is bound to scope',
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
        expect(span.data['file.path'], 'resources/test.txt');
        expect(span.data['from-cache'], true);
        expect(span.context.description, 'AssetBundle.loadString: test.txt');
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
      },
    );

    test('loadString - end span with error if exception is thrown', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      await expectLater(
        sut.loadString(_testFileName),
        throwsA(isA<Exception>()),
      );

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.context.description, 'AssetBundle.loadString: test.txt');
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test(
      'loadBuffer - creates a span if transaction is bound to scope',
      () async {
        final sut = fixture.getSut();
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        await sut.loadBuffer(_testFileName);

        await tr.finish();

        final tracer = (tr as SentryTracer);
        final span = tracer.children.first;

        expect(span.status, SpanStatus.ok());
        expect(span.finished, true);
        expect(span.context.operation, 'file.read');
        expect(span.data['file.path'], 'resources/test.txt');
        expect(span.data['file.size'], 12);
        expect(span.context.description, 'AssetBundle.loadBuffer: test.txt');
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
      },
    );

    test('loadBuffer - end span with error if exception is thrown', () async {
      final sut = fixture.getSut(throwException: true);
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      try {
        await sut.loadBuffer(_testFileName);
      } catch (_) {}

      await tr.finish();

      final tracer = (tr as SentryTracer);
      final span = tracer.children.first;

      expect(span.status, SpanStatus.internalError());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(span.context.description, 'AssetBundle.loadBuffer: test.txt');
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test(
      'loadStructuredData - does not create any spans and just forwards the call to the underlying assetbundle if disabled',
      () async {
        final sut = fixture.getSut(structuredDataTracing: false);
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
      'loadStructuredData - finish with errored span if loading fails',
      () async {
        final sut = fixture.getSut(throwException: true);
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );
        await expectLater(
          sut.loadStructuredData<String>(
            _testFileName,
            (value) async => value.toString(),
          ),
          throwsA(isA<Exception>()),
        );

        await tr.finish();

        final tracer = (tr as SentryTracer);
        final span = tracer.children.first;

        expect(span.status, SpanStatus.internalError());
        expect(span.finished, true);
        expect(span.throwable, isA<Exception>());
        expect(span.context.operation, 'file.read');
        expect(
          span.context.description,
          'AssetBundle.loadStructuredData<String>: test.txt',
        );
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
      },
    );

    test(
      'loadStructuredData - finish with errored span if parsing fails',
      () async {
        final sut = fixture.getSut(throwException: false);
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );
        await expectLater(
          sut.loadStructuredData<String>(
            _testFileName,
            (value) async => throw Exception('error while parsing'),
          ),
          throwsA(isA<Exception>()),
        );

        await tr.finish();

        final tracer = (tr as SentryTracer);
        var span = tracer.children.first;

        expect(tracer.children.length, 2);

        expect(span.status, SpanStatus.internalError());
        expect(span.finished, true);
        expect(span.throwable, isA<Exception>());
        expect(span.context.operation, 'file.read');
        expect(
          span.context.description,
          'AssetBundle.loadStructuredData<String>: test.txt',
        );
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);

        span = tracer.children[1];

        expect(span.status, SpanStatus.internalError());
        expect(span.finished, true);
        expect(span.throwable, isA<Exception>());
        expect(span.context.operation, 'serialize.file.read');
        expect(
          span.context.description,
          'parsing "resources/test.txt" to "String"',
        );
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
      },
    );

    test('loadStructuredData - finish with successfully', () async {
      final sut = fixture.getSut(throwException: false);
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      await sut.loadStructuredData<String>(
        _testFileName,
        (value) async => value.toString(),
      );

      await tr.finish();

      final tracer = (tr as SentryTracer);
      var span = tracer.children.first;

      expect(tracer.children.length, 2);

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(
        span.context.description,
        'AssetBundle.loadStructuredData<String>: test.txt',
      );
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);

      span = tracer.children[1];

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'serialize.file.read');
      expect(
        span.context.description,
        'parsing "resources/test.txt" to "String"',
      );
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test(
      'loadStructuredBinaryData - does not create any spans and just forwords the call to the underlying assetbundle if disabled',
      () async {
        final sut = fixture.getSut(structuredDataTracing: false);
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );

        final data = await sut.loadStructuredBinaryData<String>(
          _testFileName,
          (value) async => utf8.decode(
            value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes),
          ),
        );
        expect(data, 'Hello World!');

        await tr.finish();

        final tracer = (tr as SentryTracer);

        expect(tracer.children.length, 0);
      },
    );

    test(
      'loadStructuredBinaryData - finish with errored span if loading fails',
      () async {
        final sut = fixture.getSut(throwException: true);
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );
        await expectLater(
          sut.loadStructuredBinaryData<String>(
            _testFileName,
            (value) async => utf8.decode(
              value.buffer.asUint8List(
                value.offsetInBytes,
                value.lengthInBytes,
              ),
            ),
          ),
          throwsA(isA<Exception>()),
        );

        await tr.finish();

        final tracer = (tr as SentryTracer);
        final span = tracer.children.first;

        expect(span.status, SpanStatus.internalError());
        expect(span.finished, true);
        expect(span.throwable, isA<Exception>());
        expect(span.context.operation, 'file.read');
        expect(
          span.context.description,
          'AssetBundle.loadStructuredBinaryData<String>: test.txt',
        );
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
      },
    );

    test(
      'loadStructuredBinaryData - finish with errored span if parsing fails',
      () async {
        final sut = fixture.getSut(throwException: false);
        final tr = fixture._hub.startTransaction(
          'name',
          'op',
          bindToScope: true,
        );
        await expectLater(
          sut.loadStructuredBinaryData<String>(
            _testFileName,
            (value) async => throw Exception('error while parsing'),
          ),
          throwsA(isA<Exception>()),
        );

        await tr.finish();

        final tracer = (tr as SentryTracer);

        expect(tracer.children.length, 2);

        var span = tracer.children[0];

        expect(span.status, SpanStatus.internalError());
        expect(span.finished, true);
        expect(span.throwable, isA<Exception>());
        expect(span.context.operation, 'file.read');
        expect(
          span.context.description,
          'AssetBundle.loadStructuredBinaryData<String>: test.txt',
        );

        span = tracer.children[1];

        expect(span.status, SpanStatus.internalError());
        expect(span.finished, true);
        expect(span.throwable, isA<Exception>());
        expect(span.context.operation, 'serialize.file.read');
        expect(
          span.context.description,
          'parsing "resources/test.txt" to "String"',
        );
        expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
      },
    );

    test('loadStructuredBinaryData - finish with successfully', () async {
      final sut = fixture.getSut(throwException: false);
      final tr = fixture._hub.startTransaction('name', 'op', bindToScope: true);

      await sut.loadStructuredBinaryData<String>(
        _testFileName,
        (value) async => utf8.decode(
          value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes),
        ),
      );

      await tr.finish();

      final tracer = (tr as SentryTracer);

      expect(tracer.children.length, 2);

      var span = tracer.children[0];

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'file.read');
      expect(
        span.context.description,
        'AssetBundle.loadStructuredBinaryData<String>: test.txt',
      );
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);

      span = tracer.children[1];

      expect(span.status, SpanStatus.ok());
      expect(span.finished, true);
      expect(span.context.operation, 'serialize.file.read');
      expect(
        span.context.description,
        'parsing "resources/test.txt" to "String"',
      );
      expect(span.origin, SentryTraceOrigins.autoFileAssetBundle);
    });

    test('ends both spans when a binary parser throws synchronously', () async {
      final sut = fixture.getSut();
      final transaction =
          fixture._hub.startTransaction('parent', 'test', bindToScope: true)
              as SentryTracer;
      final error = StateError('parsing failed');

      await expectLater(
        sut.loadStructuredBinaryData<int>(_testFileName, (_) => throw error),
        throwsA(same(error)),
      );
      await transaction.finish();

      expect(transaction.children, hasLength(2));
      for (final span in transaction.children) {
        expect(span.finished, isTrue);
        expect(span.status, const SpanStatus.internalError());
        expect(span.throwable, same(error));
      }
    });

    test('evict call gets forwarded', () {
      final sut = fixture.getSut();

      sut.evict(_testFileName);

      expect(fixture.assetBundle.evictKey, _testFileName);
    });
  });
}

class Fixture {
  final _options = defaultTestOptions()
    ..traceLifecycle = SentryTraceLifecycle.static;
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
    bool structuredDataTracing = true,
  }) {
    when(transport.send(any)).thenAnswer((_) async => SentryId.newId());
    return SentryAssetBundle(
      enableStructuredDataTracing: structuredDataTracing,
      hub: _hub,
      bundle: assetBundle..throwException = throwException,
    );
  }
}

class TestAssetBundle extends CachingAssetBundle {
  bool throwException = false;
  String? evictKey;

  @override
  // ignore: override_on_non_overriding_member
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) async {
    if (throwException) {
      throw Exception('exception thrown for testing purposes');
    }
    if (key == _testFileName) {
      return parser(
        ByteData.view(Uint8List.fromList(utf8.encode('Hello World!')).buffer),
      );
    }
    return parser(ByteData(0));
  }

  @override
  Future<ByteData> load(String key) async {
    if (throwException) {
      throw Exception('exception thrown for testing purposes');
    }
    if (key == _testFileName) {
      return ByteData.view(
        Uint8List.fromList(utf8.encode('Hello World!')).buffer,
      );
    }
    return ByteData(0);
  }

  @override
  void evict(String key) {
    super.evict(key);
    evictKey = key;
  }

  @override
  // This is an override on Flutter greater than 3.1
  // ignore: override_on_non_overriding_member
  Future<ImmutableBuffer> loadBuffer(String key) async {
    if (throwException) {
      throw Exception('exception thrown for testing purposes');
    }
    if (key == _testFileName) {
      return ImmutableBuffer.fromUint8List(
        Uint8List.fromList(utf8.encode('Hello World!')),
      );
    }
    return ImmutableBuffer.fromUint8List(Uint8List.fromList([]));
  }
}

class StreamingFixture {
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
  final processor = MockTelemetryProcessor();
  final spans = <RecordingSentrySpanV2>[];
  final assetBundle = TestAssetBundle();
  late final hub = Hub(options);

  StreamingFixture() {
    options.telemetryProcessor = processor;
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span case final RecordingSentrySpanV2 span) {
        spans.add(span);
      }
    });
    InstrumentationSpanFactorySetupIntegration().call(hub, options);
  }

  RecordingSentrySpanV2? findSpanByOperation(String operation) {
    return spans
        .where((span) => span.attributes['sentry.op']?.value == operation)
        .firstOrNull;
  }

  SentryAssetBundle getSut({bool structuredDataTracing = true}) {
    return SentryAssetBundle(
      hub: hub,
      bundle: assetBundle,
      enableStructuredDataTracing: structuredDataTracing,
    );
  }
}
