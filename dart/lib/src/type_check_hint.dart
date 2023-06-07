import 'http_client/failed_request_client.dart';

/// Constants used for Type Check hints.
class TypeCheckHint {
  /// Used for Synthetic exceptions.
  static const syntheticException = 'syntheticException';

  /// Used for [FailedRequestClient] for request hint
  static const httpRequest = 'request';

  /// Used for [FailedRequestClient] for response hint
  static const httpResponse = 'response';

  /// Used for `sentry_logging/LoggingIntegration` for `sentry_logging/LogRecord` hint
  static const record = 'record';

  /// Widget that was tapped in `sentry_flutter/SentryUserInteractionWidget`
  static const widget = 'widget';
}
