/// The Span statuses
class SpanStatus {
  const SpanStatus._(
    this._value,
    this._minHttpStatusCode, {
    int? maxHttpStatusCode,
  }) : _maxHttpStatusCode = maxHttpStatusCode ?? _minHttpStatusCode;

  /// Not an error, returned on success.
  const SpanStatus.ok() : this._('ok', 200, maxHttpStatusCode: 299);

  /// The operation was cancelled, typically by the caller.
  const SpanStatus.cancelled() : this._('cancelled', 499);

  /// Some invariants expected by the underlying system have been broken.
  /// This code is reserved for serious errors.
  const SpanStatus.internalError() : this._('internal_error', 500);

  /// An unknown error raised by APIs that don't return enough error information.
  const SpanStatus.unknown() : this._('unknown', 500);

  /// An unknown error raised by APIs that don't return enough error information.
  const SpanStatus.unknownError() : this._('unknown_error', 500);

  /// The client specified an invalid argument.
  const SpanStatus.invalidArgument() : this._('invalid_argument', 400);

  /// The deadline expired before the operation could succeed.
  const SpanStatus.deadlineExceeded() : this._('deadline_exceeded', 504);

  /// Content was not found or request was denied for an entire class of users.
  const SpanStatus.notFound() : this._('not_found', 404);

  /// The entity attempted to be created already exists
  const SpanStatus.alreadyExists() : this._('already_exists', 409);

  /// The caller doesn't have permission to execute the specified operation.
  const SpanStatus.permissionDenied() : this._('permission_denied', 403);

  /// The resource has been exhausted e.g. per-user quota exhausted, file system out of space.
  const SpanStatus.resourceExhausted() : this._('resource_exhausted', 429);

  /// The client shouldn't retry until the system state has been explicitly handled.
  const SpanStatus.failedPrecondition() : this._('failed_precondition', 400);

  /// The operation was aborted.
  const SpanStatus.aborted() : this._('aborted', 409);

  /// The operation was attempted past the valid range e.g. seeking past the end of a file.
  const SpanStatus.outOfRange() : this._('out_of_range', 400);

  /// The operation is not implemented or is not supported/enabled for this operation.
  const SpanStatus.unimplemented() : this._('unimplemented', 501);

  /// The service is currently available e.g. as a transient condition.
  const SpanStatus.unavailable() : this._('unavailable', 503);

  /// Unrecoverable data loss or corruption.
  const SpanStatus.dataLoss() : this._('data_loss', 500);

  /// The requester doesn't have valid authentication credentials for the operation.
  const SpanStatus.unauthenticated() : this._('unauthenticated', 401);

  final String _value;
  final int _minHttpStatusCode;
  final int _maxHttpStatusCode;

  @override
  String toString() => _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  bool operator ==(o) {
    if (o is SpanStatus) {
      return o._value == _value &&
          o._minHttpStatusCode == _minHttpStatusCode &&
          o._maxHttpStatusCode == _maxHttpStatusCode;
    }
    return false;
  }

  /// Creates SpanStatus from HTTP status code.
  factory SpanStatus.fromHttpStatusCode(
    int httpStatusCode, {
    SpanStatus? fallback,
  }) {
    var status = SpanStatus.ok();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.cancelled();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.unknown();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.invalidArgument();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.deadlineExceeded();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.notFound();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.alreadyExists();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.permissionDenied();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.resourceExhausted();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.unimplemented();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.unavailable();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    status = SpanStatus.unauthenticated();
    if (_matches(status, httpStatusCode)) {
      return status;
    }
    return fallback ?? SpanStatus.unknownError();
  }

  /// Creates SpanStatus from a String.
  factory SpanStatus.fromString(String value) => SpanStatus._(value, 0);

  static bool _matches(SpanStatus status, int code) =>
      code >= status._minHttpStatusCode && code <= status._maxHttpStatusCode;
}
