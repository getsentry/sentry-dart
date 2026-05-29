// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:grpc/src/generated/google/rpc/error_details.pb.dart' as rpc;
import 'package:sentry/sentry.dart';
import 'package:sentry/src/constants.dart';
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

  // Headers that may contain credentials; omitted unless sendDefaultPii is on.
  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'proxy-authorization',
  };

  /// Creates a [SentryGrpcInterceptor].
  ///
  /// [captureFailedRequests] overrides [SentryOptions.captureFailedRequests].
  /// When `null`, the global option is used.
  ///
  /// Set [recordBreadcrumbs] to `false` to disable breadcrumb recording.
  ///
  /// Set [captureRequestHeaders] to `false` to suppress attaching outgoing
  /// gRPC metadata (request headers) to the span. Sensitive headers
  /// (`authorization`, `cookie`, etc.) are redacted unless
  /// [SentryOptions.sendDefaultPii] is enabled. Defaults to `true`.
  SentryGrpcInterceptor({
    Hub? hub,
    bool? captureFailedRequests,
    bool recordBreadcrumbs = true,
    bool captureRequestHeaders = true,
  })  : _hub = hub ?? HubAdapter(),
        _captureFailedRequests = captureFailedRequests,
        _recordBreadcrumbs = recordBreadcrumbs,
        _captureRequestHeaders = captureRequestHeaders {
    _spanFactory = _hub.options.spanFactory;
    if (_hub.options.isTracingEnabled()) {
      _hub.options.sdk.addIntegration(integrationName);
    }
    _hub.options.sdk.addPackage(packageName, sdkVersion);
  }

  final Hub _hub;
  final bool? _captureFailedRequests;
  final bool _recordBreadcrumbs;
  final bool _captureRequestHeaders;
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

    if (span != null) {
      _attachRpcAttributes(span, method.path);
      _attachRequestData(span, method, request, options);
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
          if (span != null && grpcError != null) {
            _attachErrorDetails(span, grpcError);
          }
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

  // Sets rpc.system.name and rpc.method per OTEL gRPC semconv.
  // methodPath format is /package.Service/Method; rpc.method strips the leading slash.
  void _attachRpcAttributes(InstrumentationSpan span, String methodPath) {
    span.setData(SemanticAttributesConstants.rpcSystemName, 'grpc');
    if (methodPath.startsWith('/')) {
      span.setData(
        SemanticAttributesConstants.rpcMethod,
        methodPath.substring(1),
      );
    }
  }

  void _attachRequestData<Q, R>(
    InstrumentationSpan span,
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
  ) {
    if (_captureRequestHeaders) {
      final sendPii = _hub.options.sendDefaultPii;
      options.metadata.forEach((key, value) {
        final normalizedKey = key.toLowerCase();
        if (!sendPii && _sensitiveHeaders.contains(normalizedKey)) return;
        span.setData(
          '${SemanticAttributesConstants.rpcRequestMetadataPrefix}$normalizedKey',
          value,
        );
      });
    }
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

  void _attachErrorDetails(InstrumentationSpan span, GrpcError error) {
    final details = error.details;
    if (details == null || details.isEmpty) return;

    for (final detail in details) {
      if (detail is rpc.ErrorInfo) {
        span.setData(
          SemanticAttributesConstants.grpcErrorInfoReason,
          detail.reason,
        );
        span.setData(
          SemanticAttributesConstants.grpcErrorInfoDomain,
          detail.domain,
        );
        if (detail.metadata.isNotEmpty && _hub.options.sendDefaultPii) {
          span.setData(
            SemanticAttributesConstants.grpcErrorInfoMetadata,
            detail.metadata.toString(),
          );
        }
      } else if (detail is rpc.BadRequest) {
        span.setData(
          SemanticAttributesConstants.grpcBadRequestFieldViolations,
          detail.fieldViolations
              .map((v) => '${v.field_1}: ${v.description}')
              .join('; '),
        );
      } else if (detail is rpc.RetryInfo) {
        span.setData(
          SemanticAttributesConstants.grpcRetryInfoRetryDelay,
          '${detail.retryDelay.seconds}s',
        );
      } else if (detail is rpc.DebugInfo) {
        span.setData(
          SemanticAttributesConstants.grpcDebugInfoDetail,
          detail.detail,
        );
      } else if (detail is rpc.PreconditionFailure) {
        span.setData(
          SemanticAttributesConstants.grpcPreconditionFailureViolations,
          detail.violations
              .map((v) => '${v.type}: ${v.subject} - ${v.description}')
              .join('; '),
        );
      } else if (detail is rpc.ResourceInfo) {
        span.setData(
          SemanticAttributesConstants.grpcResourceInfoType,
          detail.resourceType,
        );
        span.setData(
          SemanticAttributesConstants.grpcResourceInfoName,
          detail.resourceName,
        );
        span.setData(
          SemanticAttributesConstants.grpcResourceInfoDescription,
          detail.description,
        );
      } else if (detail is rpc.QuotaFailure) {
        span.setData(
          SemanticAttributesConstants.grpcQuotaFailureViolations,
          detail.violations
              .map((v) => '${v.subject}: ${v.description}')
              .join('; '),
        );
      }
    }
  }

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
