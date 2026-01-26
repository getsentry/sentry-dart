// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

import 'extension.dart';
import 'version.dart';

/// An [Integration] which listens to all messages of the
/// [logging](https://pub.dev/packages/logging) package.
class LoggingIntegration implements Integration<SentryOptions> {
  /// Creates the [LoggingIntegration].
  ///
  /// - All log events equal or higher than [minBreadcrumbLevel] are recorded as a
  /// [Breadcrumb].
  /// - All log events equal or higher than [minEventLevel] are recorded as a
  /// [SentryEvent].
  /// - All log events equal or higher than [minSentryLogLevel] are logged to
  /// Sentry, if [SentryOptions.enableLogs] is true.
  ///
  /// Log levels are mapped to the following Sentry log levels methods:
  ///
  /// | Dart Log Level        | Sentry Log Level |
  /// |-----------------------|------------------|
  /// | SHOUT, SEVERE         | error            |
  /// | WARNING               | warn             |
  /// | INFO                  | info             |
  /// | CONFIG, FINE, ALL     | debug            |
  /// | FINER, FINEST         | trace            |
  ///
  /// Custom log levels are mapped based on their numeric values:
  /// - >= 1000 → error
  /// - >= 900 → warn
  /// - >= 800 → info
  /// - >= 700 || 500 || 0 → debug
  /// - < 700 → trace
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

  @internal
  // ignore: public_member_api_docs
  static const origin = 'auto.log.logging';

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
        'loggerName': SentryAttribute.string(record.loggerName),
        'sequenceNumber': SentryAttribute.int(record.sequenceNumber),
        'time': SentryAttribute.int(record.time.millisecondsSinceEpoch),
        'sentry.origin': SentryAttribute.string(origin),
      };

      // Map log levels based on value ranges
      final levelValue = record.level.value;
      if (levelValue >= Level.SEVERE.value) {
        // >= 1000 → error
        await _options.logger.error(record.message, attributes: attributes);
      } else if (levelValue >= Level.WARNING.value) {
        // >= 900 → warn
        await _options.logger.warn(record.message, attributes: attributes);
      } else if (levelValue >= Level.INFO.value) {
        // >= 800 → info
        await _options.logger.info(record.message, attributes: attributes);
      } else if (levelValue >= Level.CONFIG.value ||
          levelValue == Level.FINE.value ||
          levelValue == Level.ALL.value) {
        // >= 700 || 500 || 0 → debug
        await _options.logger.debug(record.message, attributes: attributes);
      } else {
        // < 700 → trace
        await _options.logger.trace(record.message, attributes: attributes);
      }
    }
  }
}
