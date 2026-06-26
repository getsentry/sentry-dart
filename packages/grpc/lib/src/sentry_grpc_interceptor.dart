// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:async';

import 'package:grpc/grpc_or_grpcweb.dart';
import 'package:grpc/service_api.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/constants.dart';
import 'package:sentry/src/tracing/instrumentation/instrumentation.dart';
import 'package:sentry/src/utils/tracing_utils.dart';

import 'internal_logger.dart';
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
@experimental
class SentryGrpcInterceptor extends ClientInterceptor {
  /// Integration name registered with the Sentry SDK.
  static const String integrationName = 'GrpcClient';

  /// Creates a [SentryGrpcInterceptor].
  ///
  /// [captureFailedRequests] overrides [SentryOptions.captureFailedRequests].
  /// When `null`, the global option is used.
  ///
  /// Set [enableBreadcrumbs] to `false` to disable breadcrumb recording.
  SentryGrpcInterceptor({
    Hub? hub,
    bool? captureFailedRequests,
    bool enableBreadcrumbs = true,
  })  : _hub = hub ?? HubAdapter(),
        _captureFailedRequests = captureFailedRequests,
        _recordBreadcrumbs = enableBreadcrumbs {
    _spanFactory = _hub.options.spanFactory;
    _hub.options.sdk.addIntegration(integrationName);
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
    if (parentSpan == null) {
      internalLogger.debug(
        'No active span found. Skipping tracing for gRPC call: ${method.path}',
      );
    }
    final span = parentSpan != null
        ? _spanFactory.createSpan(
            parentSpan: parentSpan,
            operation: 'grpc.client',
            description: method.path,
          )
        : null;

    span?.origin = SentryTraceOrigins.autoGrpcClientInterceptor;

    if (span != null) {
      _attachRpcAttributes(span, method.path);
      _attachRequestData(span, options);
    }

    final modifiedOptions = _buildModifiedOptions(options, span, method.path);
    final stopwatch = _recordBreadcrumbs ? (Stopwatch()..start()) : null;
    final response = invoker(method, request, modifiedOptions);

    unawaited(
      response.then(
        (_) async {
          span?.status = const SpanStatus.ok();
          span?.setData(
            SemanticAttributesConstants.rpcResponseStatusCode,
            'OK',
          );
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
        onError: (Object error, StackTrace stackTrace) async {
          final grpcError = error is GrpcError ? error : null;
          span?.throwable = error;
          span?.status = _grpcStatusToSpanStatus(grpcError);
          span?.setData(
            SemanticAttributesConstants.rpcResponseStatusCode,
            grpcError?.codeName ?? 'UNKNOWN',
          );
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
            internalLogger.debug(
              'Capturing exception for failed gRPC call: ${method.path}',
            );
            await _captureGrpcException(
              error,
              method.path,
              grpcError,
              stackTrace,
            );
          }
        },
      ),
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
    final modifiedOptions =
        _buildModifiedOptions(options, parentSpan, method.path);
    return invoker(method, requests, modifiedOptions);
  }

  // Sets rpc.system, rpc.service, and rpc.method per OTel gRPC semconv.
  // methodPath format: /package.Service/Method
  void _attachRpcAttributes(InstrumentationSpan span, String methodPath) {
    span.setData(SemanticAttributesConstants.rpcSystem, 'grpc');
    final path =
        methodPath.startsWith('/') ? methodPath.substring(1) : methodPath;
    final slash = path.lastIndexOf('/');
    if (slash != -1) {
      span.setData(
          SemanticAttributesConstants.rpcService, path.substring(0, slash));
      span.setData(
          SemanticAttributesConstants.rpcMethod, path.substring(slash + 1));
    }
  }

  void _attachRequestData(
    InstrumentationSpan span,
    CallOptions options,
  ) {
    if (!_hub.options.sendDefaultPii) return;
    options.metadata.forEach((key, value) {
      final normalizedKey = key.toLowerCase();
      span.setData(
        '${SemanticAttributesConstants.rpcRequestMetadataPrefix}$normalizedKey',
        value,
      );
    });
  }

  CallOptions _buildModifiedOptions(
    CallOptions options,
    InstrumentationSpan? span,
    String methodPath,
  ) {
    final headers = <String, dynamic>{};
    if (containsTargetOrMatchesRegExp(
      _hub.options.tracePropagationTargets,
      methodPath,
    )) {
      addTracingHeadersToHttpHeader(headers, _hub, span: span);
    } else {
      internalLogger.debug(
        'gRPC method $methodPath does not match tracePropagationTargets. '
        'Skipping injection of Sentry trace headers.',
      );
    }
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
    StackTrace stackTrace,
  ) =>
      _hub.captureException(
        error,
        stackTrace: stackTrace,
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
      StatusCode.unknown => const SpanStatus.unknown(),
      StatusCode.invalidArgument => const SpanStatus.invalidArgument(),
      StatusCode.notFound => const SpanStatus.notFound(),
      StatusCode.alreadyExists => const SpanStatus.alreadyExists(),
      StatusCode.permissionDenied => const SpanStatus.permissionDenied(),
      StatusCode.unauthenticated => const SpanStatus.unauthenticated(),
      StatusCode.resourceExhausted => const SpanStatus.resourceExhausted(),
      StatusCode.failedPrecondition => const SpanStatus.failedPrecondition(),
      StatusCode.aborted => const SpanStatus.aborted(),
      StatusCode.outOfRange => const SpanStatus.outOfRange(),
      StatusCode.unimplemented => const SpanStatus.unimplemented(),
      StatusCode.unavailable => const SpanStatus.unavailable(),
      StatusCode.deadlineExceeded => const SpanStatus.deadlineExceeded(),
      StatusCode.dataLoss => const SpanStatus.dataLoss(),
      _ => const SpanStatus.internalError(),
    };
  }
}
