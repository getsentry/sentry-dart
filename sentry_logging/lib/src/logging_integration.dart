import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';
import 'version.dart';
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
  LoggingIntegration({
    Level minBreadcrumbLevel = Level.INFO,
    Level minEventLevel = Level.SEVERE,
  })  : _minBreadcrumbLevel = minBreadcrumbLevel,
        _minEventLevel = minEventLevel;

  final Level _minBreadcrumbLevel;
  final Level _minEventLevel;
  late StreamSubscription<LogRecord> _subscription;
  late Hub _hub;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _hub = hub;
    _setSdkVersion(options);
    _subscription = Logger.root.onRecord.listen(
      _onLog,
      onError: (Object error, StackTrace stackTrace) async {
        await _hub.captureException(error, stackTrace: stackTrace);
      },
    );
    options.sdk.addIntegration('LoggingIntegration');
  }

  @override
  Future<void> close() async {
    await super.close();
    await _subscription.cancel();
  }

  void _setSdkVersion(SentryOptions options) {
    final sdk = SdkVersion(
      name: sdkName,
      version: sdkVersion,
      integrations: options.sdk.integrations,
      packages: options.sdk.packages,
    );
    sdk.addPackage('pub:sentry_logging', sdkVersion);
    options.sdk = sdk;
  }

  bool _isLoggable(Level logLevel, Level minLevel) {
    return logLevel > minLevel;
  }

  void _onLog(LogRecord record) async {
    // The event must be logged first, otherwise the log would also be added
    // to the breadcrumbs for itself.
    if (_isLoggable(record.level, _minEventLevel)) {
      await _hub.captureEvent(
        record.toEvent(),
        stackTrace: record.stackTrace,
      );
    }

    if (_isLoggable(record.level, _minBreadcrumbLevel)) {
      _hub.addBreadcrumb(record.toBreadcrumb());
    }
  }
}
