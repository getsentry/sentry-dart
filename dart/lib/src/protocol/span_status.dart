import 'dart:async';

import 'package:http/http.dart';

// maybe should be an enum instead of a class?
class SpanStatus {
  const SpanStatus._(this._value);

  /// Not an error, returned on success.
  const SpanStatus.ok() : this._('ok');

  /// The operation was cancelled, typically by the caller.
  const SpanStatus.cancelled() : this._('cancelled');

  /// Some invariants expected by the underlying system have been broken.
  /// This code is reserved for serious errors.
  const SpanStatus.internalError() : this._('internal_error');

  /// An unknown error raised by APIs that don't return enough error information.
  const SpanStatus.unknown() : this._('unknown');

  /// An unknown error raised by APIs that don't return enough error information.
  const SpanStatus.unknownError() : this._('unknown_error');

  /// The client specified an invalid argument.
  const SpanStatus.invalidArgument() : this._('invalid_argument');

  /// The deadline expired before the operation could succeed.
  const SpanStatus.deadlineExceeded() : this._('deadline_exceeded');

  /// Content was not found or request was denied for an entire class of users.
  const SpanStatus.notFound() : this._('not_found');

  /// The entity attempted to be created already exists
  const SpanStatus.alreadyExists() : this._('already_exists');

  /// The caller doesn't have permission to execute the specified operation.
  const SpanStatus.permissionDenied() : this._('permission_denied');

  /// The resource has been exhausted e.g. per-user quota exhausted, file system out of space.
  const SpanStatus.resourceExhausted() : this._('resource_exhausted');

  /// The client shouldn't retry until the system state has been explicitly handled.
  const SpanStatus.failedPrecondition() : this._('failed_precondition');

  /// The operation was aborted.
  const SpanStatus.aborted() : this._('aborted');

  /// The operation was attempted past the valid range e.g. seeking past the end of a file.
  const SpanStatus.outOfRange() : this._('out_of_range');

  /// The operation is not implemented or is not supported/enabled for this operation.
  const SpanStatus.unimplemented() : this._('unimplemented');

  /// The service is currently available e.g. as a transient condition.
  const SpanStatus.unavailable() : this._('unavailable');

  /// Unrecoverable data loss or corruption.
  const SpanStatus.dataLoss() : this._('data_loss');

  /// The requester doesn't have valid authentication credentials for the operation.
  const SpanStatus.unauthenticated() : this._('unauthenticated');

  final String _value;

  @override
  String toString() => _value;

  /// Creates SpanStatus from HTTP status code.
  factory SpanStatus.fromHttpStatusCode(
    int httpStatusCode, {
    SpanStatus? fallback,
  }) {
    if (httpStatusCode < 400) {
      return SpanStatus.ok();
    } else if (httpStatusCode == 400) {
      return SpanStatus.invalidArgument();
    } else if (httpStatusCode == 401) {
      return SpanStatus.unauthenticated();
    } else if (httpStatusCode == 403) {
      return SpanStatus.permissionDenied();
    } else if (httpStatusCode == 404) {
      return SpanStatus.notFound();
    } else if (httpStatusCode == 409) {
      return SpanStatus.alreadyExists();
    } else if (httpStatusCode == 429) {
      return SpanStatus.resourceExhausted();
    } else if (httpStatusCode < 500) {
      return SpanStatus.invalidArgument();
    } else if (httpStatusCode == 500) {
      return SpanStatus.internalError();
    } else if (httpStatusCode == 501) {
      return SpanStatus.unimplemented();
    } else if (httpStatusCode == 503) {
      return SpanStatus.unavailable();
    } else if (httpStatusCode == 504) {
      return SpanStatus.deadlineExceeded();
    } else if (httpStatusCode < 600) {
      return SpanStatus.internalError();
    }
    return fallback ?? SpanStatus.unknownError();
  }

  factory SpanStatus.fromString(String? value) {
    return _all.firstWhere(
      (e) => e.toString() == value,
      orElse: () => SpanStatus.unknown(),
    );
  }

  factory SpanStatus.fromType(Type? value) {
    return _exceptionMap[value] ?? SpanStatus.unknown();
  }

  /// Adds mapping from error types to SpanStatus.
  /// Overwrites mapping if a key already exists.
  static void registerExceptions(Map<Type, SpanStatus> exceptions) {
    _exceptionMap.addAll(exceptions);
  }

  /// Platform independend exceptions and errors.
  /// Dart:IO, Dart:HTML and Flutter needs to be added later, because this
  /// code is platform independend.
  static final Map<Type, SpanStatus> _exceptionMap = {
    Exception: SpanStatus.internalError(),
    FormatException: SpanStatus.failedPrecondition(),
    Error: SpanStatus.internalError(),
    AssertionError: SpanStatus.failedPrecondition(),
    ClientException: SpanStatus.internalError(),
    TimeoutException: SpanStatus.deadlineExceeded(),
    NoSuchMethodError: SpanStatus.unimplemented(),
  };

  static const List<SpanStatus> _all = [
    SpanStatus.ok(),
    SpanStatus.cancelled(),
    SpanStatus.internalError(),
    SpanStatus.unknown(),
    SpanStatus.invalidArgument(),
    SpanStatus.deadlineExceeded(),
    SpanStatus.notFound(),
    SpanStatus.alreadyExists(),
    SpanStatus.permissionDenied(),
    SpanStatus.resourceExhausted(),
    SpanStatus.failedPrecondition(),
    SpanStatus.aborted(),
    SpanStatus.outOfRange(),
    SpanStatus.unimplemented(),
    SpanStatus.unavailable(),
    SpanStatus.dataLoss(),
    SpanStatus.unauthenticated(),
  ];
}
