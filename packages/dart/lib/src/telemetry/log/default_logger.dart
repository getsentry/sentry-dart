import 'dart:async';

import '../../../sentry.dart';
import '../../sentry_template_string.dart';
import '../../utils/internal_logger.dart';

typedef CaptureLogCallback = FutureOr<void> Function(SentryLog log);
typedef ScopeProvider = Scope Function();

final class DefaultSentryLogger implements SentryLogger {
  final CaptureLogCallback _captureLogCallback;
  final ClockProvider _clockProvider;
  final ScopeProvider _defaultScopeProvider;

  late final SentryLoggerFormatter _formatter =
      _DefaultSentryLoggerFormatter(this);

  DefaultSentryLogger({
    required CaptureLogCallback captureLogCallback,
    required ClockProvider clockProvider,
    required ScopeProvider defaultScopeProvider,
  })  : _captureLogCallback = captureLogCallback,
        _clockProvider = clockProvider,
        _defaultScopeProvider = defaultScopeProvider;

  @override
  FutureOr<void> trace(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.trace("$body") called with attributes ${_formatAttributes(attributes)}');
    return _captureLog(SentryLogLevel.trace, body,
        attributes: attributes, scope: scope);
  }

  @override
  FutureOr<void> debug(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.debug("$body") called with attributes ${_formatAttributes(attributes)}');
    return _captureLog(SentryLogLevel.debug, body,
        attributes: attributes, scope: scope);
  }

  @override
  FutureOr<void> info(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.info("$body") called with attributes ${_formatAttributes(attributes)}');
    return _captureLog(SentryLogLevel.info, body,
        attributes: attributes, scope: scope);
  }

  @override
  FutureOr<void> warn(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.warn("$body") called with attributes ${_formatAttributes(attributes)}');
    return _captureLog(SentryLogLevel.warn, body,
        attributes: attributes, scope: scope);
  }

  @override
  FutureOr<void> error(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.error("$body") called with attributes ${_formatAttributes(attributes)}');
    return _captureLog(SentryLogLevel.error, body,
        attributes: attributes, scope: scope);
  }

  @override
  FutureOr<void> fatal(
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    internalLogger.debug(() =>
        'Sentry.logger.fatal("$body") called with attributes ${_formatAttributes(attributes)}');
    return _captureLog(SentryLogLevel.fatal, body,
        attributes: attributes, scope: scope);
  }

  @override
  SentryLoggerFormatter get fmt => _formatter;

  // Helpers

  FutureOr<void> _captureLog(
    SentryLogLevel level,
    String body, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    final log = SentryLog(
      timestamp: _clockProvider(),
      level: level,
      body: body,
      traceId: _traceIdFor(scope),
      spanId: _activeSpanIdFor(scope),
      attributes: attributes ?? {},
    );

    return _captureLogCallback(log);
  }

  SentryId _traceIdFor(Scope? scope) =>
      (scope ?? _defaultScopeProvider()).propagationContext.traceId;

  SpanId? _activeSpanIdFor(Scope? scope) =>
      (scope ?? _defaultScopeProvider()).span?.context.spanId;

  String _formatAttributes(Map<String, SentryAttribute>? attributes) {
    final formatted = attributes?.toFormattedString() ?? '';
    return formatted.isEmpty ? '' : ' $formatted';
  }
}

final class _DefaultSentryLoggerFormatter implements SentryLoggerFormatter {
  _DefaultSentryLoggerFormatter(this._logger);

  final DefaultSentryLogger _logger;

  @override
  FutureOr<void> trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.trace(formattedBody,
            attributes: allAttributes, scope: scope);
      },
    );
  }

  @override
  FutureOr<void> debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.debug(formattedBody,
            attributes: allAttributes, scope: scope);
      },
    );
  }

  @override
  FutureOr<void> info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.info(formattedBody,
            attributes: allAttributes, scope: scope);
      },
    );
  }

  @override
  FutureOr<void> warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.warn(formattedBody,
            attributes: allAttributes, scope: scope);
      },
    );
  }

  @override
  FutureOr<void> error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.error(formattedBody,
            attributes: allAttributes, scope: scope);
      },
    );
  }

  @override
  FutureOr<void> fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
    Scope? scope,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.fatal(formattedBody,
            attributes: allAttributes, scope: scope);
      },
    );
  }

  // Helper

  FutureOr<void> _format(
    String templateBody,
    List<dynamic> arguments,
    Map<String, SentryAttribute>? attributes,
    FutureOr<void> Function(String, Map<String, SentryAttribute>) callback,
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
    return callback(formattedBody, templateAttributes);
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
