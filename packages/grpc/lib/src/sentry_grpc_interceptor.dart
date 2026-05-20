// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'package:grpc/grpc.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/instrumentation.dart';
import 'package:sentry/src/utils/tracing_utils.dart';

import 'version.dart';

/// A gRPC [ClientInterceptor] that adds Sentry instrumentation to outgoing RPC calls.
///
/// For each unary call, the interceptor:
/// - Creates a child span under the active transaction (legacy) or active span (span-first).
/// - Injects `sentry-trace` and `baggage` headers into the call metadata for distributed tracing.
/// - Records a breadcrumb with the method path, status, and duration.
/// - Optionally captures failed RPCs (non-OK status codes or transport errors) as Sentry exceptions.
///
/// Server-streaming calls receive header injection only; full span lifecycle tracking
/// for streaming RPCs will be added in a future release.
///
/// ```dart
/// final channel = ClientChannel('api.example.com');
/// final interceptor = SentryGrpcInterceptor();
/// final stub = GreeterClient(channel, interceptors: [interceptor]);
/// ```
///
/// To capture failed RPCs (overriding [SentryOptions.captureFailedRequests]):
///
/// ```dart
/// final interceptor = SentryGrpcInterceptor(captureFailedRequests: true);
/// ```
class SentryGrpcInterceptor extends ClientInterceptor {
  /// Integration name registered with the Sentry SDK.
  static const String integrationName = 'GrpcClientTracing';

  /// Creates a [SentryGrpcInterceptor].
  ///
  /// [captureFailedRequests] overrides [SentryOptions.captureFailedRequests].
  /// When `null`, the global option is used.
  ///
  /// Set [recordBreadcrumbs] to `false` to disable breadcrumb recording.
  SentryGrpcInterceptor({
    Hub? hub,
    bool? captureFailedRequests,
    bool recordBreadcrumbs = true,
  })  : _hub = hub ?? HubAdapter(),
        _captureFailedRequests = captureFailedRequests,
        _recordBreadcrumbs = recordBreadcrumbs {
    _spanFactory = _hub.options.spanFactory;
    if (_hub.options.isTracingEnabled()) {
      _hub.options.sdk.addIntegration(integrationName);
    }
    _hub.options.sdk.addPackage(packageName, sdkVersion);
  }

  final Hub _hub;
  final bool? _captureFailedRequests;
  final bool _recordBreadcrumbs;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final parentSpan = _spanFactory.getSpan(_hub);
    final span = parentSpan != null
        ? _spanFactory.createSpan(
            parentSpan: parentSpan,
            operation: 'grpc.client',
            description: method.path,
          )
        : null;

    span?.origin = SentryTraceOrigins.autoGrpcClientInterceptor;

    final modifiedOptions = _buildModifiedOptions(options, span);
    final stopwatch = _recordBreadcrumbs ? (Stopwatch()..start()) : null;
    final response = invoker(method, request, modifiedOptions);

    response.then(
      (_) async {
        span?.status = const SpanStatus.ok();
        await span?.finish();
        if (_recordBreadcrumbs) {
          stopwatch!.stop();
          await _addBreadcrumb(
            method.path,
            StatusCode.ok,
            'OK',
            stopwatch.elapsed,
            SentryLevel.info,
          );
        }
      },
      onError: (Object error) async {
        final grpcError = error is GrpcError ? error : null;
        span?.throwable = error;
        span?.status = _grpcStatusToSpanStatus(grpcError);
        await span?.finish();
        if (_recordBreadcrumbs) {
          stopwatch!.stop();
          await _addBreadcrumb(
            method.path,
            grpcError?.code ?? StatusCode.unknown,
            grpcError?.codeName ?? 'UNKNOWN',
            stopwatch.elapsed,
            SentryLevel.error,
          );
        }
        if (_shouldCapture(grpcError)) {
          await _captureGrpcException(error, method.path, grpcError);
        }
      },
    );

    return response;
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    // Inject trace headers; full span lifecycle for streaming will be added later.
    final parentSpan = _spanFactory.getSpan(_hub);
    final modifiedOptions = _buildModifiedOptions(options, parentSpan);
    return invoker(method, requests, modifiedOptions);
  }

  CallOptions _buildModifiedOptions(
    CallOptions options,
    InstrumentationSpan? span,
  ) {
    final headers = <String, dynamic>{};
    addTracingHeadersToHttpHeader(headers, _hub, span: span);
    return options.mergedWith(
      CallOptions(
        metadata: {
          for (final entry in headers.entries) entry.key: entry.value as String,
        },
      ),
    );
  }

  Future<void> _addBreadcrumb(
    String methodPath,
    int statusCode,
    String statusName,
    Duration duration,
    SentryLevel level,
  ) =>
      _hub.addBreadcrumb(
        Breadcrumb(
          type: 'grpc',
          category: 'grpc.client',
          level: level,
          data: {
            'method': methodPath,
            'status_code': statusCode,
            'status': statusName,
            'duration_ms': duration.inMilliseconds,
          },
        ),
      );

  bool _shouldCapture(GrpcError? grpcError) {
    final enabled =
        _captureFailedRequests ?? _hub.options.captureFailedRequests;
    if (!enabled) return false;
    return grpcError == null || grpcError.code != StatusCode.ok;
  }

  Future<void> _captureGrpcException(
    Object error,
    String methodPath,
    GrpcError? grpcError,
  ) =>
      _hub.captureException(
        error,
        withScope: (scope) {
          scope.setContexts('gRPC', {
            'method': methodPath,
            if (grpcError != null) ...{
              'status_code': grpcError.code,
              'status': grpcError.codeName,
              if (grpcError.message != null) 'message': grpcError.message,
            },
          });
        },
      );

  SpanStatus _grpcStatusToSpanStatus(GrpcError? error) {
    if (error == null) return const SpanStatus.internalError();
    return switch (error.code) {
      StatusCode.ok => const SpanStatus.ok(),
      StatusCode.cancelled => const SpanStatus.cancelled(),
      StatusCode.invalidArgument => const SpanStatus.invalidArgument(),
      StatusCode.notFound => const SpanStatus.notFound(),
      StatusCode.permissionDenied => const SpanStatus.permissionDenied(),
      StatusCode.unauthenticated => const SpanStatus.unauthenticated(),
      StatusCode.resourceExhausted => const SpanStatus.resourceExhausted(),
      StatusCode.unimplemented => const SpanStatus.unimplemented(),
      StatusCode.unavailable => const SpanStatus.unavailable(),
      StatusCode.deadlineExceeded => const SpanStatus.deadlineExceeded(),
      _ => const SpanStatus.internalError(),
    };
  }
}
