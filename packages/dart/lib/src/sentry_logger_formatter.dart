import 'dart:async';
import 'protocol/sentry_log_attribute.dart';
import 'sentry_template_string.dart';
import 'sentry_logger.dart';

class SentryLoggerFormatter {
  SentryLoggerFormatter(this._logger);

  final SentryLogger _logger;

  FutureOr<void> trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.trace(formattedBody, attributes: allAttributes);
      },
    );
  }

  FutureOr<void> debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.debug(formattedBody, attributes: allAttributes);
      },
    );
  }

  FutureOr<void> info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.info(formattedBody, attributes: allAttributes);
      },
    );
  }

  FutureOr<void> warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.warn(formattedBody, attributes: allAttributes);
      },
    );
  }

  FutureOr<void> error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.error(formattedBody, attributes: allAttributes);
      },
    );
  }

  FutureOr<void> fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    return _format(
      templateBody,
      arguments,
      attributes,
      (formattedBody, allAttributes) {
        return _logger.fatal(formattedBody, attributes: allAttributes);
      },
    );
  }

  // Helper

  FutureOr<void> _format(
    String templateBody,
    List<dynamic> arguments,
    Map<String, SentryLogAttribute>? attributes,
    FutureOr<void> Function(String, Map<String, SentryLogAttribute>) callback,
  ) {
    String formattedBody;
    Map<String, SentryLogAttribute> templateAttributes;

    if (arguments.isEmpty) {
      // No arguments means no template processing needed
      formattedBody = templateBody;
      templateAttributes = <String, SentryLogAttribute>{};
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

  Map<String, SentryLogAttribute> _getAllAttributes(
    String templateBody,
    List<dynamic> args,
  ) {
    final templateAttributes = {
      'sentry.message.template': SentryLogAttribute.string(templateBody),
    };
    for (var i = 0; i < args.length; i++) {
      final argument = args[i];
      final key = 'sentry.message.parameter.$i';
      if (argument is String) {
        templateAttributes[key] = SentryLogAttribute.string(argument);
      } else if (argument is int) {
        templateAttributes[key] = SentryLogAttribute.int(argument);
      } else if (argument is bool) {
        templateAttributes[key] = SentryLogAttribute.bool(argument);
      } else if (argument is double) {
        templateAttributes[key] = SentryLogAttribute.double(argument);
      } else {
        try {
          templateAttributes[key] =
              SentryLogAttribute.string(argument.toString());
        } catch (e) {
          templateAttributes[key] = SentryLogAttribute.string("");
        }
      }
    }
    return templateAttributes;
  }
}
