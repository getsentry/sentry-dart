import 'package:meta/meta.dart';

/// The Message Interface carries a log message that describes an event or error.
/// Optionally, it can carry a format string and structured parameters. This can help to group similar messages into the same issue.
/// example of a serialized message : {
///   "message": {
///     "message": "My raw message with interpreted strings like %s",
///     "params": ["this"]
///   }
/// }
@immutable
class SentryMessage {
  /// The fully formatted message. If missing, Sentry will try to interpolate the message.
  final String formatted;

  /// The raw message string (uninterpolated).
  /// example : "My raw message with interpreted strings like %s",
  final String? template;

  /// A list of formatting parameters, preferably strings. Non-strings will be coerced to strings.
  final List<dynamic>? params;

  const SentryMessage(this.formatted, {this.template, this.params});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    json['formatted'] = formatted;

    if (template != null) {
      json['message'] = template;
    }

    if (params?.isNotEmpty ?? false) {
      json['params'] = params;
    }

    return json;
  }

  SentryMessage copyWith({
    String? formatted,
    String? template,
    List<dynamic>? params,
  }) =>
      SentryMessage(
        formatted ?? this.formatted,
        template: template ?? this.template,
        params: params ?? this.params,
      );
}
