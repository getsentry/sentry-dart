import 'package:meta/meta.dart';

import 'client.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'stack_trace.dart';

/// Sentry SDK main entry point
///
class Sentry {
  static SentryClient _client;

  Sentry._();

  static void init(SentryOptions options) {
    _client = SentryClient(
      dsn: options.dsn,
      environmentAttributes: options.environmentAttributes,
      compressPayload: options.compressPayload,
      httpClient: options.httpClient,
      clock: options.clock,
      uuidGenerator: options.uuidGenerator,
    );
  }

  /// Initializes the SDK
  static void initDns(String dns) => _client = SentryClient(dsn: dns);

  /// Reports an [event] to Sentry.io.
  static Future<SentryResponse> captureEvent(
    Event event, {
    StackFrameFilter stackFrameFilter,
  }) async {
    return _client.captureEvent(
      event: event,
      stackFrameFilter: stackFrameFilter,
    );
  }

  /// Reports the [exception] and optionally its [stackTrace] to Sentry.io.
  static Future<SentryResponse> captureException(
    dynamic error, {
    dynamic stackTrace,
  }) async {
    return _client.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  }

  /// Close the client SDK
  static Future<void> close() async => _client.close();

  /// client injector only use for testing
  @visibleForTesting
  static void initClient(SentryClient client) => _client = client;
}
