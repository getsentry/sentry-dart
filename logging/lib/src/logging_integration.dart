import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

import 'extension.dart';
import 'version.dart';

/// An [Integration] which listens to all messages of the
/// [logging](https://pub.dev/packages/logging) package.
class LoggingIntegration implements Integration<SentryOptions> {
  /// Creates a [LoggingIntegration] to capture log events into Sentry.
  ///
  /// The integration listens to all log records and:
  ///  - Converts records at or above [minBreadcrumbLevel] into a [Breadcrumb] and adds them to the scope.
  ///  - Converts records at or above [minEventLevel] into a [SentryEvent] and captures it.
  ///  - Sends records at or above [minLogLevel] to Sentry as “logs” when [SentryOptions.enableLogs] is true).
  ///
  /// Parameters:
  ///  - [minBreadcrumbLevel]: the lowest level at which to record a breadcrumb.
  ///    Defaults to [SentryLevel.INFO].
  ///  - [minEventLevel]: the lowest level at which to capture a Sentry event.
  ///    Defaults to [SentryLevel.SEVERE].
  ///  - [minSentryLogLevel]: the lowest level at which to forward the log record
  ///    itself to Sentry as a log entry (if Sentry logs are enabled).
  ///    Defaults to [SentryLevel.INFO].
  LoggingIntegration({
    Level minBreadcrumbLevel = Level.INFO,
    Level minEventLevel = Level.SEVERE,
    Level minSentryLogLevel = Level.INFO,
  })  : _minBreadcrumbLevel = minBreadcrumbLevel,
        _minEventLevel = minEventLevel,
        _minSentryLogLevel = minSentryLogLevel;

  final Level _minBreadcrumbLevel;
  final Level _minEventLevel;
  final Level _minSentryLogLevel;
  late StreamSubscription<LogRecord> _subscription;
  late Hub _hub;
  late SentryOptions _options;

  @override
  void call(Hub hub, SentryOptions options) {
    _hub = hub;
    _options = options;
    _subscription = Logger.root.onRecord.listen(
      _onLog,
      onError: (Object error, StackTrace stackTrace) async {
        await _hub.captureException(error, stackTrace: stackTrace);
      },
    );
    options.sdk.addPackage(packageName, sdkVersion);
    options.sdk.addIntegration('LoggingIntegration');
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
  }

  bool _isLoggable(Level logLevel, Level minLevel) {
    if (logLevel == Level.OFF) {
      return false;
    }
    return logLevel >= minLevel;
  }

  Future<void> _onLog(LogRecord record) async {
    // The event must be logged first, otherwise the log would also be added
    // to the breadcrumbs for itself.
    if (_isLoggable(record.level, _minEventLevel)) {
      await _hub.captureEvent(
        record.toEvent(),
        stackTrace: record.stackTrace,
        hint: Hint.withMap({TypeCheckHint.record: record}),
      );
    }

    if (_isLoggable(record.level, _minBreadcrumbLevel)) {
      await _hub.addBreadcrumb(
        record.toBreadcrumb(),
        hint: Hint.withMap({TypeCheckHint.record: record}),
      );
    }

    if (_options.enableLogs && _isLoggable(record.level, _minSentryLogLevel)) {
      final attributes = {
        'loggerName': SentryLogAttribute.string(record.loggerName),
        'sequenceNumber': SentryLogAttribute.int(record.sequenceNumber),
        'time': SentryLogAttribute.int(record.time.millisecondsSinceEpoch),
      };

      switch (record.level) {
        case Level.SHOUT:
          await _options.logger.error(record.message, attributes: attributes);
          break;
        case Level.SEVERE:
          await _options.logger.error(record.message, attributes: attributes);
          break;
        case Level.WARNING:
          await _options.logger.warn(record.message, attributes: attributes);
          break;
        case Level.INFO:
          await _options.logger.info(record.message, attributes: attributes);
          break;
        case Level.CONFIG:
          await _options.logger.debug(record.message, attributes: attributes);
          break;
        case Level.FINE:
          await _options.logger.debug(record.message, attributes: attributes);
          break;
        case Level.FINER:
          await _options.logger.trace(record.message, attributes: attributes);
          break;
        case Level.FINEST:
          await _options.logger.trace(record.message, attributes: attributes);
          break;
        case Level.ALL:
          await _options.logger.debug(record.message, attributes: attributes);
          break;
      }
    }
  }
}
