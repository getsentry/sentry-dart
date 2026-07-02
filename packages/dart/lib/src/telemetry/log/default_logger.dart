import 'dart:async';

import '../../../sentry.dart';
import '../../sentry_template_string.dart';
import '../../utils/internal_logger.dart';

typedef CaptureLogCallback = Future<void> Function(SentryLog log);
typedef ScopeProvider = Scope Function();

final class DefaultSentryLogger implements SentryLogger {
  final CaptureLogCallback _captureLogCallback;
  final ClockProvider _clockProvider;
  final ScopeProvider _scopeProvider;

  late final SentryLoggerFormatter _formatter =
      _DefaultSentryLoggerFormatter(this);

  DefaultSentryLogger({
    required CaptureLogCallback captureLogCallback,
    required ClockProvider clockProvider,
    required ScopeProvider scopeProvider,
  })  : _captureLogCallback = captureLogCallback,
        _clockProvider = clockProvider,
        _scopeProvider = scopeProvider;

  @override
  void trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _captureLog(SentryLogLevel.trace, body, attributes: attributes);
  }

  @override
  void debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _captureLog(SentryLogLevel.debug, body, attributes: attributes);
  }

  @override
  void info(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _captureLog(SentryLogLevel.info, body, attributes: attributes);
  }

  @override
  void warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _captureLog(SentryLogLevel.warn, body, attributes: attributes);
  }

  @override
  void error(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _captureLog(SentryLogLevel.error, body, attributes: attributes);
  }

  @override
  void fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _captureLog(SentryLogLevel.fatal, body, attributes: attributes);
  }

  @override
  SentryLoggerFormatter get fmt => _formatter;

  // Helpers

  void _captureLog(
    SentryLogLevel level,
    String body, {
    Map<String, SentryAttribute>? attributes,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.${level.value}("$body") called with attributes ${_formatAttributes(attributes)}');

    final log = SentryLog(
      timestamp: _clockProvider(),
      level: level,
      body: body,
      traceId: _scopeProvider().propagationContext.traceId,
      spanId: _scopeProvider().span?.context.spanId,
      attributes: attributes ?? {},
    );

    unawaited(_captureLogCallback(log));
  }

  String _formatAttributes(Map<String, SentryAttribute>? attributes) {
    final formatted = attributes?.toFormattedString() ?? '';
    return formatted.isEmpty ? '' : ' $formatted';
  }
}

final class _DefaultSentryLoggerFormatter implements SentryLoggerFormatter {
  _DefaultSentryLoggerFormatter(this._logger);

  final DefaultSentryLogger _logger;

  @override
  void trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        _logger.trace(formattedBody, attributes: allAttributes);
      },
    );
  }

  @override
  void debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        _logger.debug(formattedBody, attributes: allAttributes);
      },
    );
  }

  @override
  void info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        _logger.info(formattedBody, attributes: allAttributes);
      },
    );
  }

  @override
  void warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        _logger.warn(formattedBody, attributes: allAttributes);
      },
    );
  }

  @override
  void error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        _logger.error(formattedBody, attributes: allAttributes);
      },
    );
  }

  @override
  void fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
  }) {
    _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        _logger.fatal(formattedBody, attributes: allAttributes);
      },
    );
  }

  // Helper

  void _format(
    String templateBody,
    List<dynamic> arguments,
    Map<String, SentryAttribute>? attributes,
    void Function(String, Map<String, SentryAttribute>) callback,
  ) {
    String formattedBody;
    Map<String, SentryAttribute> templateAttributes;

    if (arguments.isEmpty) {
      // No arguments means no template processing needed
      formattedBody = templateBody;
      templateAttributes = <String, SentryAttribute>{};
    } else {
      // Process template with arguments
      final templateString = SentryTemplateString(templateBody, arguments);
      formattedBody = templateString.format();
      templateAttributes = _getAllAttributes(templateBody, arguments);
    }

    if (attributes != null) {
      templateAttributes.addAll(attributes);
    }
    callback(formattedBody, templateAttributes);
  }

  Map<String, SentryAttribute> _getAllAttributes(
    String templateBody,
    List<dynamic> args,
  ) {
    final templateAttributes = {
      'sentry.message.template': SentryAttribute.string(templateBody),
    };
    for (var i = 0; i < args.length; i++) {
      final argument = args[i];
      final key = 'sentry.message.parameter.$i';
      if (argument is String) {
        templateAttributes[key] = SentryAttribute.string(argument);
      } else if (argument is int) {
        templateAttributes[key] = SentryAttribute.int(argument);
      } else if (argument is bool) {
        templateAttributes[key] = SentryAttribute.bool(argument);
      } else if (argument is double) {
        templateAttributes[key] = SentryAttribute.double(argument);
      } else {
        try {
          templateAttributes[key] = SentryAttribute.string(argument.toString());
        } catch (e) {
          templateAttributes[key] = SentryAttribute.string("");
        }
      }
    }
    return templateAttributes;
  }
}
