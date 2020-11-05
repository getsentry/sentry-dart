import 'package:meta/meta.dart';

import 'mechanism.dart';
import 'sentry_stack_trace.dart';

/// The Exception Interface specifies an exception or error that occurred in a program.
class SentryException {
  /// Required. The type of exception
  final String type;

  /// Required. The value of the exception
  final String value;

  /// The optional module, or package which the exception type lives in.
  final String module;

  /// An optional stack trace object
  final SentryStackTrace stacktrace;

  /// An optional object describing the [Mechanism] that created this exception
  final Mechanism mechanism;

  /// Represents a thread id. not available in Dart
  final int threadId;

  const SentryException({
    @required this.type,
    @required this.value,
    this.module,
    this.stacktrace,
    this.mechanism,
    this.threadId,
  });

  Map<String, dynamic> toJson() {
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
      json['stacktrace'] = stacktrace.toJson();
    }

    if (mechanism != null) {
      json['mechanism'] = mechanism.toJson();
    }

    return json;
  }
}
