import 'package:meta/meta.dart';
import 'http_client/breadcrumb_client.dart';
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

  /// Used to indicate that the SDK added a synthetic current stack trace.
  static const currentStackTrace = 'currentStackTrace';

  @internal
  static const isWidgetFeedback = 'isWidgetFeedback';

  /// Session Replay's captured request detail for an `http` breadcrumb, set
  /// by [BreadcrumbClient] when its injected network details capturer
  /// captures one. Replay-only: never persisted on the breadcrumb itself so
  /// it can't leak into events unrelated to Session Replay.
  @internal
  static const replayNetworkRequestDetail = 'replayNetworkRequestDetail';

  /// Session Replay's captured response detail for an `http` breadcrumb, set
  /// by [BreadcrumbClient] when its injected network details capturer
  /// captures one. Replay-only: never persisted on the breadcrumb itself so
  /// it can't leak into events unrelated to Session Replay.
  @internal
  static const replayNetworkResponseDetail = 'replayNetworkResponseDetail';
}
