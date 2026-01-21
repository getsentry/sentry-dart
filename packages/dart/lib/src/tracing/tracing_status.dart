import 'package:meta/meta.dart';

/// Implementation-agnostic status for tracing operations.
///
/// This enum provides a common status type that can be mapped to
/// implementation-specific status types (e.g., Sentry's SpanStatus,
/// OpenTelemetry's StatusCode).
@experimental
enum TracingStatus {
  /// The operation completed successfully.
  ok,

  /// The operation was cancelled.
  cancelled,

  /// Unknown error.
  unknown,

  /// Client specified an invalid argument.
  invalidArgument,

  /// Deadline expired before operation could complete.
  deadlineExceeded,

  /// Requested entity was not found.
  notFound,

  /// Entity that we attempted to create already exists.
  alreadyExists,

  /// Permission denied.
  permissionDenied,

  /// Resource exhausted (e.g., rate limiting).
  resourceExhausted,

  /// Operation rejected due to system state.
  failedPrecondition,

  /// Operation was aborted.
  aborted,

  /// Operation attempted past valid range.
  outOfRange,

  /// Operation not implemented or supported.
  unimplemented,

  /// Internal error.
  internalError,

  /// Service unavailable.
  unavailable,

  /// Data loss.
  dataLoss,

  /// Unauthenticated request.
  unauthenticated,
}

/// Extension methods for [TracingStatus].
@experimental
extension TracingStatusExtension on TracingStatus {
  /// Creates a [TracingStatus] from an HTTP status code.
  ///
  /// Maps HTTP status codes to appropriate tracing statuses:
  /// - 2xx: [TracingStatus.ok]
  /// - 400: [TracingStatus.invalidArgument]
  /// - 401: [TracingStatus.unauthenticated]
  /// - 403: [TracingStatus.permissionDenied]
  /// - 404: [TracingStatus.notFound]
  /// - 409: [TracingStatus.alreadyExists]
  /// - 429: [TracingStatus.resourceExhausted]
  /// - 499: [TracingStatus.cancelled]
  /// - 500: [TracingStatus.internalError]
  /// - 501: [TracingStatus.unimplemented]
  /// - 503: [TracingStatus.unavailable]
  /// - 504: [TracingStatus.deadlineExceeded]
  /// - Other 4xx: [TracingStatus.invalidArgument]
  /// - Other 5xx: [TracingStatus.internalError]
  static TracingStatus fromHttpStatusCode(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return TracingStatus.ok;
    }

    switch (statusCode) {
      case 400:
        return TracingStatus.invalidArgument;
      case 401:
        return TracingStatus.unauthenticated;
      case 403:
        return TracingStatus.permissionDenied;
      case 404:
        return TracingStatus.notFound;
      case 409:
        return TracingStatus.alreadyExists;
      case 429:
        return TracingStatus.resourceExhausted;
      case 499:
        return TracingStatus.cancelled;
      case 500:
        return TracingStatus.internalError;
      case 501:
        return TracingStatus.unimplemented;
      case 503:
        return TracingStatus.unavailable;
      case 504:
        return TracingStatus.deadlineExceeded;
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return TracingStatus.invalidArgument;
        }
        if (statusCode >= 500) {
          return TracingStatus.internalError;
        }
        return TracingStatus.unknown;
    }
  }
}
