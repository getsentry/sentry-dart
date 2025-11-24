import 'dart:async';
import 'protocol/sentry_attribute.dart';
import 'sentry_template_string.dart';
import 'sentry_logger.dart';

class SentryLoggerFormatter {
  SentryLoggerFormatter(this._logger);

  final SentryLogger _logger;

  FutureOr<void> trace(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryAttribute>? attributes,
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
    Map<String, SentryAttribute>? attributes,
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
    Map<String, SentryAttribute>? attributes,
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
    Map<String, SentryAttribute>? attributes,
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
    Map<String, SentryAttribute>? attributes,
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
    Map<String, SentryAttribute>? attributes,
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
