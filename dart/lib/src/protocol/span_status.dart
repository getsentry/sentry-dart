class SpanStatus {
  const SpanStatus(int httpStatusCode)
      : _minHttpStatusCode = httpStatusCode,
        _maxHttpStatusCode = httpStatusCode;

  const SpanStatus.range(this._minHttpStatusCode, this._maxHttpStatusCode);

  /// Not an error, returned on success.
  const SpanStatus.ok() : this.range(200, 299);

  /// The operation was cancelled, typically by the caller.
  const SpanStatus.cancelled() : this(499);

  /// Some invariants expected by the underlying system have been broken.
  /// This code is reserved for serious errors.
  const SpanStatus.internalError() : this(500);

  /// An unknown error raised by APIs that don't return enough error information.
  const SpanStatus.unknown() : this(500);

  /// An unknown error raised by APIs that don't return enough error information.
  const SpanStatus.unknownError() : this(500);

  /// The client specified an invalid argument.
  const SpanStatus.invalidArgument() : this(400);

  /// The deadline expired before the operation could succeed.
  const SpanStatus.deadlineExceeded() : this(504);

  /// Content was not found or request was denied for an entire class of users.
  const SpanStatus.notFound() : this(404);

  /// The entity attempted to be created already exists
  const SpanStatus.alreadyExists() : this(409);

  /// The caller doesn't have permission to execute the specified operation.
  const SpanStatus.permissionDenied() : this(403);

  /// The resource has been exhausted e.g. per-user quota exhausted, file system out of space.
  const SpanStatus.resourceExhausted() : this(429);

  /// The client shouldn't retry until the system state has been explicitly handled.
  const SpanStatus.failedPrecondition() : this(400);

  /// The operation was aborted.
  const SpanStatus.aborted() : this(409);

  /// The operation was attempted past the valid range e.g. seeking past the end of a file.
  const SpanStatus.outOfRange() : this(400);

  /// The operation is not implemented or is not supported/enabled for this operation.
  const SpanStatus.unimplemented() : this(501);

  /// The service is currently available e.g. as a transient condition.
  const SpanStatus.unavailable() : this(503);

  /// Unrecoverable data loss or corruption.
  const SpanStatus.dataLoss() : this(500);

  /// The requester doesn't have valid authentication credentials for the operation.
  const SpanStatus.unauthenticated() : this(401);

  /// Creates SpanStatus from HTTP status code.
  static SpanStatus? fromHttpStatusCode(
    int? httpStatusCode, {
    SpanStatus? defaultStatus,
  }) {
    final spanStatus = httpStatusCode != null
        // currently throws StackOverflow because of recursion
        ? fromHttpStatusCode(httpStatusCode)
        : defaultStatus;
    return spanStatus ?? defaultStatus;
  }

  final int _minHttpStatusCode;
  final int _maxHttpStatusCode;

  bool matches(int httpStatusCode) {
    return httpStatusCode >= _minHttpStatusCode &&
        httpStatusCode <= _maxHttpStatusCode;
  }

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
