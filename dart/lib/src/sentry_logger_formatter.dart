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
    final templateString = SentryTemplateString(templateBody);
    final interpolatedBody = templateString.format(arguments);
    final allAttributes = _getTemplateAttributes(templateBody, arguments);
    if (attributes != null) {
      allAttributes.addAll(attributes);
    }
    return _logger.trace(interpolatedBody, attributes: allAttributes);
  }

  FutureOr<void> debug(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    final templateString = SentryTemplateString(templateBody);
    final interpolatedBody = templateString.format(arguments);
    final allAttributes = _getTemplateAttributes(templateBody, arguments);
    if (attributes != null) {
      allAttributes.addAll(attributes);
    }
    return _logger.debug(interpolatedBody, attributes: allAttributes);
  }

  FutureOr<void> info(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    final templateString = SentryTemplateString(templateBody);
    final interpolatedBody = templateString.format(arguments);
    final allAttributes = _getTemplateAttributes(templateBody, arguments);
    if (attributes != null) {
      allAttributes.addAll(attributes);
    }
    return _logger.info(interpolatedBody, attributes: allAttributes);
  }

  FutureOr<void> warn(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    final templateString = SentryTemplateString(templateBody);
    final interpolatedBody = templateString.format(arguments);
    final allAttributes = _getTemplateAttributes(templateBody, arguments);
    if (attributes != null) {
      allAttributes.addAll(attributes);
    }
    return _logger.warn(interpolatedBody, attributes: allAttributes);
  }

  FutureOr<void> error(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    final templateString = SentryTemplateString(templateBody);
    final interpolatedBody = templateString.format(arguments);
    final allAttributes = _getTemplateAttributes(templateBody, arguments);
    if (attributes != null) {
      allAttributes.addAll(attributes);
    }
    return _logger.error(interpolatedBody, attributes: allAttributes);
  }

  FutureOr<void> fatal(
    String templateBody,
    List<dynamic> arguments, {
    Map<String, SentryLogAttribute>? attributes,
  }) {
    final templateString = SentryTemplateString(templateBody);
    final interpolatedBody = templateString.format(arguments);
    final allAttributes = _getTemplateAttributes(templateBody, arguments);
    if (attributes != null) {
      allAttributes.addAll(attributes);
    }
    return _logger.fatal(interpolatedBody, attributes: allAttributes);
  }

  // Helper

  Map<String, SentryLogAttribute> _getTemplateAttributes(
      String templateBody, List<dynamic> args) {
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
