import 'package:sentry/sentry.dart';
import 'package:sentry/src/protocol/level.dart';

class DiagnosticLogger {
  final Logger _logger;
  final SentryOptions _options;

  DiagnosticLogger(this._logger, this._options);

  void log(SeverityLevel level, String message) {
    if (_isEnabled()) {
      _logger(level, message);
    }
  }

  bool _isEnabled() {
    // TODO: if (_options.diagnosticLevel)
    return _options.debug;
  }
}
