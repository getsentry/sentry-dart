// ignore_for_file: invalid_use_of_internal_member, experimental_member_use, library_private_types_in_public_api

@TestOn('vm')
library;

import 'dart:io';

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:grpc/grpc.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/tracing/instrumentation/span_factory_integration.dart';
import 'package:sentry_grpc/src/sentry_grpc_interceptor.dart';
import 'package:sentry_grpc/src/version.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';

void main() {
  group('SentryGrpcInterceptor', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
      await fixture.setUp();
    });

    tearDown(() async {
      await fixture.tearDown();
    });

    group('when initialized', () {
      test('registers integration name when tracing is enabled', () {
        fixture.getSut();

        expect(
          fixture.hub.options.sdk.integrations,
          contains(SentryGrpcInterceptor.integrationName),
        );
      });

      test('does not register integration name when tracing is disabled', () {
        fixture.hub.options.tracesSampleRate = null;
        fixture.getSut();

        expect(
          fixture.hub.options.sdk.integrations,
          isNot(contains(SentryGrpcInterceptor.integrationName)),
        );
      });

      test('registers SDK package', () {
        fixture.getSut();

        expect(
          fixture.hub.options.sdk.packages.map((p) => p.name),
          contains(packageName),
        );
      });
    });

    group('interceptUnary', () {
      group('on success', () {
        test('creates child span with grpc.client operation', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(tracer.children, hasLength(1));
          expect(tracer.children.first.context.operation, 'grpc.client');
        });

        test('sets span description to method path', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.context.description,
            '/test.TestService/TestMethod',
          );
        });

        test('sets span status to OK', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(tracer.children.first.status, SpanStatus.ok());
        });

        test('sets span origin', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.origin,
            SentryTraceOrigins.autoGrpcClientInterceptor,
          );
        });

        test('adds success breadcrumb', () async {
          final client = fixture.getSut(mockHub: fixture.mockHub);

          await client.testMethod('hello');
          await pumpEventQueue();

          expect(fixture.mockHub.addBreadcrumbCalls, hasLength(1));
          final crumb = fixture.mockHub.addBreadcrumbCalls.first.crumb;
          expect(crumb.type, 'grpc');
          expect(crumb.category, 'grpc.client');
          expect(crumb.level, SentryLevel.info);
          expect(crumb.data?['method'], '/test.TestService/TestMethod');
          expect(crumb.data?['status'], 'OK');
          expect(crumb.data?['status_code'], StatusCode.ok);
        });

        test('does not add breadcrumbs when recordBreadcrumbs is false',
            () async {
          final client = fixture.getSut(
            mockHub: fixture.mockHub,
            recordBreadcrumbs: false,
          );

          await client.testMethod('hello');
          await pumpEventQueue();

          expect(fixture.mockHub.addBreadcrumbCalls, isEmpty);
        });

        test('injects sentry-trace header', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          expect(
            fixture.service.lastReceivedMetadata?.containsKey('sentry-trace'),
            isTrue,
          );
        });

        test('injects baggage header', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          expect(
            fixture.service.lastReceivedMetadata?.containsKey('baggage'),
            isTrue,
          );
        });

        test('injects sentry-trace header even without an active transaction',
            () async {
          final client = fixture.getSut(mockHub: fixture.mockHub);

          await client.testMethod('hello');

          expect(
            fixture.service.lastReceivedMetadata?.containsKey('sentry-trace'),
            isTrue,
          );
        });
      });

      group('on error', () {
        setUp(() {
          fixture.service.errorToThrow = GrpcError.notFound('not found');
        });

        test('sets span status to not_found for NOT_FOUND error', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(tracer.children.first.status, SpanStatus.notFound());
        });

        test('sets span throwable on error', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(tracer.children.first.throwable, isA<GrpcError>());
        });

        test('adds error breadcrumb', () async {
          final client = fixture.getSut(mockHub: fixture.mockHub);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await pumpEventQueue();

          expect(fixture.mockHub.addBreadcrumbCalls, hasLength(1));
          final crumb = fixture.mockHub.addBreadcrumbCalls.first.crumb;
          expect(crumb.level, SentryLevel.error);
          expect(crumb.data?['status_code'], StatusCode.notFound);
        });

        test('captures exception when captureFailedRequests is enabled',
            () async {
          final client = fixture.getSut(
            mockHub: fixture.mockHub,
            captureFailedRequests: true,
          );

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await pumpEventQueue();

          expect(fixture.mockHub.captureExceptionCalls, hasLength(1));
          expect(
            fixture.mockHub.captureExceptionCalls.first.throwable,
            isA<GrpcError>(),
          );
        });

        test(
            'does not capture exception when captureFailedRequests is disabled',
            () async {
          final client = fixture.getSut(
            mockHub: fixture.mockHub,
            captureFailedRequests: false,
          );

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await pumpEventQueue();

          expect(fixture.mockHub.captureExceptionCalls, isEmpty);
        });
      });

      group('span status mapping', () {
        test('sets cancelled for CANCELLED error', () async {
          fixture.service.errorToThrow = GrpcError.cancelled();
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(tracer.children.first.status, SpanStatus.cancelled());
        });

        test('sets unauthenticated for UNAUTHENTICATED error', () async {
          fixture.service.errorToThrow = GrpcError.unauthenticated();
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(tracer.children.first.status, SpanStatus.unauthenticated());
        });
      });
    });

    group('interceptStreaming', () {
      test('injects sentry-trace header', () async {
        final client = fixture.getSut(mockHub: fixture.mockHub);

        await client.testStreaming('hello').toList();

        expect(
          fixture.service.lastReceivedMetadata?.containsKey('sentry-trace'),
          isTrue,
        );
      });
    });

    group('span-first', () {
      test('creates span in streaming mode', () async {
        final client = fixture.getSut(spanFirst: true);

        late SentrySpanV2 transactionSpan;
        await fixture.spanFirstHub.startSpan(
          'test-transaction',
          (span) async {
            transactionSpan = span;
            await client.testMethod('hello');
          },
          parentSpan: null,
        );

        await fixture.spanFirstProcessor.waitForProcessing();

        final child =
            fixture.spanFirstProcessor.findSpanByOperation('grpc.client');
        expect(child, isNotNull);
        expect(child!.isEnded, isTrue);
        expect(child.status, SentrySpanStatusV2.ok);
        expect(child.parentSpan, equals(transactionSpan));
      });
    });
  });
}

// ----- Test service and client -----

class _TestService extends Service {
  @override
  String get $name => 'test.TestService';

  GrpcError? errorToThrow;
  Map<String, String>? lastReceivedMetadata;

  _TestService() {
    $addMethod(
      ServiceMethod<String, String>(
        'TestMethod',
        _handleUnary,
        false,
        false,
        (List<int> data) => String.fromCharCodes(data),
        (String value) => value.codeUnits,
      ),
    );
    $addMethod(
      ServiceMethod<String, String>(
        'TestStreaming',
        _handleServerStreaming,
        false,
        true,
        (List<int> data) => String.fromCharCodes(data),
        (String value) => value.codeUnits,
      ),
    );
  }

  Future<String> _handleUnary(ServiceCall call, Future<String> request) async {
    lastReceivedMetadata = call.clientMetadata;
    final error = errorToThrow;
    if (error != null) throw error;
    return 'pong: ${await request}';
  }

  Stream<String> _handleServerStreaming(
    ServiceCall call,
    Future<String> request,
  ) async* {
    lastReceivedMetadata = call.clientMetadata;
    final error = errorToThrow;
    if (error != null) throw error;
    yield 'pong: ${await request}';
  }
}

class _TestClient extends Client {
  static final _$testMethod = ClientMethod<String, String>(
    '/test.TestService/TestMethod',
    (String v) => v.codeUnits,
    (List<int> v) => String.fromCharCodes(v),
  );

  static final _$testStreaming = ClientMethod<String, String>(
    '/test.TestService/TestStreaming',
    (String v) => v.codeUnits,
    (List<int> v) => String.fromCharCodes(v),
  );

  _TestClient(super.channel, {super.interceptors});

  ResponseFuture<String> testMethod(String request, {CallOptions? options}) {
    return $createUnaryCall(_$testMethod, request, options: options);
  }

  ResponseStream<String> testStreaming(String request, {CallOptions? options}) {
    return $createStreamingCall(
      _$testStreaming,
      Stream.value(request),
      options: options,
    );
  }
}

// ----- Fixture -----

class Fixture {
  late Server _server;
  late ClientChannel _channel;

  late _TestService service;
  late MockHub mockHub;

  final _options = defaultTestOptions();
  late Hub hub;

  late Hub spanFirstHub;
  late FakeTelemetryProcessor spanFirstProcessor;

  Future<void> setUp() async {
    service = _TestService();
    _server = Server.create(services: [service]);
    await _server.serve(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );

    _channel = ClientChannel(
      'localhost',
      port: _server.port!,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );

    _options.tracesSampleRate = 1.0;
    hub = Hub(_options);

    mockHub = MockHub();
    mockHub.options.tracesSampleRate = 1.0;

    spanFirstProcessor = FakeTelemetryProcessor();
    final spanFirstOptions = defaultTestOptions()
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.stream
      ..telemetryProcessor = spanFirstProcessor;
    spanFirstHub = Hub(spanFirstOptions);
    spanFirstOptions.addIntegration(
      InstrumentationSpanFactorySetupIntegration(),
    );
    spanFirstOptions.integrations.last.call(spanFirstHub, spanFirstOptions);
  }

  Future<void> tearDown() async {
    await _channel.shutdown();
    await _server.shutdown();
    spanFirstProcessor.clear();
  }

  _TestClient getSut({
    Hub? mockHub,
    bool? captureFailedRequests,
    bool recordBreadcrumbs = true,
    bool spanFirst = false,
  }) {
    final interceptor = SentryGrpcInterceptor(
      hub: mockHub ?? (spanFirst ? spanFirstHub : hub),
      captureFailedRequests: captureFailedRequests,
      recordBreadcrumbs: recordBreadcrumbs,
    );
    return _TestClient(_channel, interceptors: [interceptor]);
  }
}
