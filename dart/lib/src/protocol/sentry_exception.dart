import 'mechanism.dart';
import 'sentry_stack_trace.dart';

class SentryException {
  String type;
  String value;
  String module;
  SentryStackTrace stacktrace;
  Mechanism mechanism;

  SentryException({
    this.type,
    this.value,
    this.module,
    this.stacktrace,
    this.mechanism,
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
