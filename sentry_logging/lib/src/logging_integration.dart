import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';
import 'extension.dart';

/// An [Integration] which listens to all messages of the
/// [logging](https://pub.dev/packages/logging) package.
class LoggingIntegration extends Integration<SentryOptions> {
  /// Creates the [LoggingIntegration].
  ///
  /// Setting [logExceptionAsEvent] to true (default) captures all
  /// messages with errors as an [SentryEvent] instead of an [Breadcrumb].
  /// Setting [logExceptionAsEvent] to false captures everything as
  /// [Breadcrumb]s.
  LoggingIntegration({bool logExceptionAsEvent = true})
      : _logExceptionsAsEvents = logExceptionAsEvent;

  final bool _logExceptionsAsEvents;
  late StreamSubscription<LogRecord> _subscription;
  late Hub _hub;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _hub = hub;
    _subscription = Logger.root.onRecord.listen(
      _onLog,
      onError: (Object error, StackTrace stackTrace) {
        _hub.captureException(error, stackTrace: stackTrace);
      },
    );
    options.sdk.addIntegration('LoggingIntegration');
  }

  @override
  Future<void> close() async {
    await super.close();
    await _subscription.cancel();
  }

  void _onLog(LogRecord record) {
    // Everything is just logged as a breadcrumb
    if (!_logExceptionsAsEvents) {
      _hub.addBreadcrumb(record.toBreadcrumb());
      return;
    }

    // If a LogRecord contains an exception, it gets reported as an SentryEvent
    if (record.error == null) {
      _hub.addBreadcrumb(record.toBreadcrumb());
    } else {
      _hub.captureEvent(
        record.toEvent(),
        stackTrace: record.stackTrace,
      );
    }
  }
}
