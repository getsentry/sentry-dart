import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

import 'extension.dart';
import 'version.dart';
import 'dart:collection';

/// An [Integration] which listens to all messages of the
/// [logging](https://pub.dev/packages/logging) package.
class LoggingIntegration implements Integration<SentryOptions> {
  /// Creates the [LoggingIntegration].
  ///
  /// All log events equal or higher than [minBreadcrumbLevel] are recorded as a
  /// [Breadcrumb].
  /// All log events equal or higher than [minEventLevel] are recorded as a
  /// [SentryEvent].
  LoggingIntegration({
    Level minBreadcrumbLevel = Level.INFO,
    Level minEventLevel = Level.SEVERE,
  })  : _minBreadcrumbLevel = minBreadcrumbLevel,
        _minEventLevel = minEventLevel;

  final Level _minBreadcrumbLevel;
  final Level
  _minEventLevel;
  late StreamSubscription<LogRecord> _subscription;
  late Hub _hub;

  @override
  void call(Hub hub, SentryOptions options) {
    _hub = hub;
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
  }
}
