/// Constants used for Type Check hints.
class TypeCheckHint {
  /// Used for Synthetic exceptions.
  static const syntheticException = 'syntheticException';

  /// Used for [FailedRequestClient] for request hint
  static const httpRequest = 'request';

  /// Used for [FailedRequestClient] for response hint
  static const httpResponse = 'response';

  /// Used for [LoggingIntegration] for [LogRecord] hint
  static const record = 'record';
}
