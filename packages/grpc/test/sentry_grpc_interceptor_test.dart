// ignore_for_file: invalid_use_of_internal_member, experimental_member_use, library_private_types_in_public_api

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/src/generated/google/protobuf/any.pb.dart' as pb;
import 'package:grpc/src/generated/google/protobuf/duration.pb.dart'
    as pb_duration;
import 'package:grpc/src/generated/google/rpc/error_details.pb.dart' as rpc;
import 'package:grpc/src/generated/google/rpc/status.pb.dart' as rpc_status;
import 'package:protobuf/protobuf.dart' show GeneratedMessage;
import 'package:sentry/sentry.dart';
import 'package:sentry/src/constants.dart';
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

      test('registers integration name even when tracing is disabled', () {
        fixture.hub.options.tracesSampleRate = null;
        fixture.getSut();

        expect(
          fixture.hub.options.sdk.integrations,
          contains(SentryGrpcInterceptor.integrationName),
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

        test('sets rpc.system.name and rpc.method on span', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          final tracer = tr as SentryTracer;
          final data = tracer.children.first.data;
          expect(data[SemanticAttributesConstants.rpcSystemName], 'grpc');
          expect(
            data[SemanticAttributesConstants.rpcMethod],
            'test.TestService/TestMethod',
          );
        });

        test('sets rpc.response.status_code to OK on success', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.rpcResponseStatusCode],
            'OK',
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

        test('does not add breadcrumbs when enableBreadcrumbs is false',
            () async {
          final client = fixture.getSut(
            mockHub: fixture.mockHub,
            enableBreadcrumbs: false,
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

        test('sets rpc.response.status_code to NOT_FOUND on error', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.rpcResponseStatusCode],
            'NOT_FOUND',
          );
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

      group('captureRequestHeaders', () {
        test('attaches metadata to span as rpc.request.metadata.* data',
            () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod(
            'hello',
            options: CallOptions(metadata: {'x-custom': 'value'}),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.data,
            containsPair('rpc.request.metadata.x-custom', 'value'),
          );
        });

        test('normalizes header keys to lowercase', () async {
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod(
            'hello',
            options: CallOptions(metadata: {'X-Custom': 'value'}),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.data,
            containsPair('rpc.request.metadata.x-custom', 'value'),
          );
          expect(
            tracer.children.first.data,
            isNot(contains('rpc.request.metadata.X-Custom')),
          );
        });

        test('does not attach metadata when captureRequestHeaders is false',
            () async {
          final client = fixture.getSut(captureRequestHeaders: false);
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod(
            'hello',
            options: CallOptions(metadata: {'x-custom': 'value'}),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.data.keys,
            isNot(anyElement(startsWith('rpc.request.metadata.'))),
          );
        });

        group('when sendDefaultPii is false', () {
          setUp(() {
            fixture.hub.options.sendDefaultPii = false;
          });

          test('omits sensitive headers', () async {
            final client = fixture.getSut();
            final tr =
                fixture.hub.startTransaction('name', 'op', bindToScope: true);

            await client.testMethod(
              'hello',
              options: CallOptions(
                metadata: {
                  'authorization': 'Bearer secret',
                  'cookie': 'session=abc',
                  'set-cookie': 'id=1',
                  'proxy-authorization': 'Basic xyz',
                },
              ),
            );
            await tr.finish();

            final tracer = tr as SentryTracer;
            final data = tracer.children.first.data;
            expect(data, isNot(contains('rpc.request.metadata.authorization')));
            expect(data, isNot(contains('rpc.request.metadata.cookie')));
            expect(data, isNot(contains('rpc.request.metadata.set-cookie')));
            expect(
              data,
              isNot(contains('rpc.request.metadata.proxy-authorization')),
            );
          });

          test('includes non-sensitive headers alongside sensitive ones',
              () async {
            final client = fixture.getSut();
            final tr =
                fixture.hub.startTransaction('name', 'op', bindToScope: true);

            await client.testMethod(
              'hello',
              options: CallOptions(
                metadata: {
                  'authorization': 'Bearer secret',
                  'x-custom': 'value',
                },
              ),
            );
            await tr.finish();

            final tracer = tr as SentryTracer;
            expect(
              tracer.children.first.data,
              containsPair('rpc.request.metadata.x-custom', 'value'),
            );
          });
        });

        group('when sendDefaultPii is true', () {
          setUp(() {
            fixture.hub.options.sendDefaultPii = true;
          });

          test('includes sensitive headers', () async {
            final client = fixture.getSut();
            final tr =
                fixture.hub.startTransaction('name', 'op', bindToScope: true);

            await client.testMethod(
              'hello',
              options:
                  CallOptions(metadata: {'authorization': 'Bearer secret'}),
            );
            await tr.finish();

            final tracer = tr as SentryTracer;
            expect(
              tracer.children.first.data,
              containsPair(
                'rpc.request.metadata.authorization',
                'Bearer secret',
              ),
            );
          });
        });
      });

      group('tracePropagationTargets', () {
        test('does not inject headers when method excluded by targets',
            () async {
          fixture.hub.options.tracePropagationTargets
            ..clear()
            ..add('/other.Service');
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await client.testMethod('hello');

          await tr.finish();

          expect(
            fixture.service.lastReceivedMetadata?.containsKey('sentry-trace'),
            isFalse,
          );
        });

        test('injects headers when method matches target', () async {
          fixture.hub.options.tracePropagationTargets
            ..clear()
            ..add('TestMethod');
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
      });

      group('_attachErrorDetails', () {
        test('attaches ErrorInfo reason and domain to span', () async {
          final errorInfo = rpc.ErrorInfo(
            reason: 'quota-exceeded',
            domain: 'example.com',
          );
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.resourceExhausted,
            [errorInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcErrorInfoReason],
            'quota-exceeded',
          );
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcErrorInfoDomain],
            'example.com',
          );
        });

        test('omits ErrorInfo metadata when sendDefaultPii is false', () async {
          fixture.hub.options.sendDefaultPii = false;
          final errorInfo = rpc.ErrorInfo(
            reason: 'auth-failed',
            domain: 'auth.example.com',
          )..metadata['user'] = 'alice';
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.unauthenticated,
            [errorInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.data
                .containsKey(SemanticAttributesConstants.grpcErrorInfoMetadata),
            isFalse,
          );
        });

        test('includes ErrorInfo metadata when sendDefaultPii is true',
            () async {
          fixture.hub.options.sendDefaultPii = true;
          final errorInfo = rpc.ErrorInfo(
            reason: 'auth-failed',
            domain: 'auth.example.com',
          )..metadata['user'] = 'alice';
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.unauthenticated,
            [errorInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcErrorInfoMetadata],
            isNotNull,
          );
        });

        test('attaches BadRequest field violations to span', () async {
          final badRequest = rpc.BadRequest(
            fieldViolations: [
              rpc.BadRequest_FieldViolation(
                field_1: 'email',
                description: 'invalid format',
              ),
            ],
          );
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.invalidArgument,
            [badRequest],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first.data[
                SemanticAttributesConstants.grpcBadRequestFieldViolations],
            contains('email'),
          );
        });

        test('attaches RetryInfo delay to span', () async {
          final retryInfo = rpc.RetryInfo(
            retryDelay: pb_duration.Duration(seconds: Int64(5)),
          );
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.unavailable,
            [retryInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcRetryInfoRetryDelay],
            '5s',
          );
        });

        test('attaches DebugInfo detail to span when sendDefaultPii is true',
            () async {
          fixture.hub.options.sendDefaultPii = true;
          final debugInfo = rpc.DebugInfo(detail: 'stack trace here');
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.internal,
            [debugInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcDebugInfoDetail],
            'stack trace here',
          );
        });

        test('omits DebugInfo detail from span when sendDefaultPii is false',
            () async {
          fixture.hub.options.sendDefaultPii = false;
          final debugInfo = rpc.DebugInfo(detail: 'stack trace here');
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.internal,
            [debugInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcDebugInfoDetail],
            isNull,
          );
        });

        test('attaches ResourceInfo to span', () async {
          final resourceInfo = rpc.ResourceInfo(
            resourceType: 'projects/123',
            resourceName: 'my-project',
            description: 'Project not found',
          );
          fixture.service.errorToThrow = _grpcErrorWithDetails(
            StatusCode.notFound,
            [resourceInfo],
          );
          final client = fixture.getSut();
          final tr =
              fixture.hub.startTransaction('name', 'op', bindToScope: true);

          await expectLater(
            client.testMethod('hello'),
            throwsA(isA<GrpcError>()),
          );
          await tr.finish();

          final tracer = tr as SentryTracer;
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcResourceInfoType],
            'projects/123',
          );
          expect(
            tracer.children.first
                .data[SemanticAttributesConstants.grpcResourceInfoName],
            'my-project',
          );
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

// ----- Helpers -----

/// Builds a [GrpcError] whose [details] survive the client/server wire transfer.
///
/// The grpc-dart server only serializes [GrpcError.trailers]; it does not
/// encode [GrpcError.details] to wire. We work around this by pre-encoding a
/// [Status] proto with [Any]-packed details into the `grpc-status-details-bin`
/// trailer — exactly what a real server that supports rich error details sends.
GrpcError _grpcErrorWithDetails(int code, List<GeneratedMessage> details) {
  final anyDetails = details
      .map((d) => pb.Any.pack(d, typeUrlPrefix: 'type.googleapis.com'))
      .toList();
  final status = rpc_status.Status(code: code, details: anyDetails);
  final encoded = base64Url.encode(status.writeToBuffer());
  return GrpcError.custom(code, 'test error', null, null, {
    'grpc-status-details-bin': encoded,
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
    bool enableBreadcrumbs = true,
    bool spanFirst = false,
    bool captureRequestHeaders = true,
  }) {
    final interceptor = SentryGrpcInterceptor(
      hub: mockHub ?? (spanFirst ? spanFirstHub : hub),
      captureFailedRequests: captureFailedRequests,
      enableBreadcrumbs: enableBreadcrumbs,
      captureRequestHeaders: captureRequestHeaders,
    );
    return _TestClient(_channel, interceptors: [interceptor]);
  }
}
