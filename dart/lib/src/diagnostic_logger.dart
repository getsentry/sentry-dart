import 'protocol.dart';
import 'sentry_options.dart';

class DiagnosticLogger {
  final SentryLogger _logger;
  final SentryOptions _options;

  DiagnosticLogger(this._logger, this._options);

  void log(SentryLevel level, String message) {
    if (_isEnabled(level)) {
      _logger(level, message);
    }
  }

  bool _isEnabled(SentryLevel level) {
    return _options.debug && level.ordinal >= _options.diagnosticLevel.ordinal;
  }
}
