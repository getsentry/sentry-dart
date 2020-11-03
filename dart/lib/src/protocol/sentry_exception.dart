import 'package:meta/meta.dart';

import 'mechanism.dart';
import 'sentry_stack_trace.dart';

/// The Exception Interface specifies an exception or error that occurred in a program.
class SentryException {
  /// The type of exception
  String type;

  /// The value of the exception
  String value;

  /// The optional module, or package which the exception type lives in.
  String module;

  /// An optional stack trace object
  SentryStackTrace stacktrace;

  /// An optional object describing the [Mechanism] that created this exception
  Mechanism mechanism;

  /// Represents a thread id. not available in Dart
  int threadId;

  SentryException({
    @required this.type,
    @required this.value,
    this.module,
    this.stacktrace,
    this.mechanism,
  });

  Map<String, dynamic> toJson([String origin = '']) {
    final json = <String, dynamic>{};

    if (type != null) {
      json['type'] = type;
    }

    if (value != null) {
      json['value'] = value;
    }

    if (module != null) {
      json['module'] = module;
    }

    if (stacktrace != null) {
      json['stacktrace'] = stacktrace.toJson(origin);
    }

    if (mechanism != null) {
      json['mechanism'] = mechanism.toJson();
    }

    return json;
  }
}
