import 'package:meta/meta.dart';

import '../protocol.dart';

/// The Exception Interface specifies an exception or error that occurred in a program.
@immutable
class SentryException {
  /// Required. The type of exception
  final String? type;

  /// Required. The value of the exception
  final String? value;

  /// The optional module, or package which the exception type lives in.
  final String? module;

  /// An optional stack trace object
  final SentryStackTrace? stackTrace;

  /// An optional object describing the [Mechanism] that created this exception
  final Mechanism? mechanism;

  /// Represents a thread id. not available in Dart
  final int? threadId;

  const SentryException({
    required this.type,
    required this.value,
    this.module,
    this.stackTrace,
    this.mechanism,
    this.threadId,
  });

  factory SentryException.fromJson(Map<String, dynamic> json) {
    return SentryException(
        type: json['type'],
        value: json['value'],
        module: json['module'],
        stackTrace: json['stacktrace'] != null
            ? SentryStackTrace.fromJson(json['stacktrace'])
            : null,
        mechanism: json['mechanism'] != null
            ? Mechanism.fromJson(json['mechanism'])
            : null,
        threadId: json['thread_id']);
  }

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

    if (stackTrace != null) {
      json['stacktrace'] = stackTrace!.toJson();
    }

    if (mechanism != null) {
      json['mechanism'] = mechanism!.toJson();
    }

    if (threadId != null) {
      json['thread_id'] = threadId;
    }

    return json;
  }

  SentryException copyWith({
    String? type,
    String? value,
    String? module,
    SentryStackTrace? stackTrace,
    Mechanism? mechanism,
    int? threadId,
  }) =>
      SentryException(
        type: type ?? this.type,
        value: value ?? this.value,
        module: module ?? this.module,
        stackTrace: stackTrace ?? this.stackTrace,
        mechanism: mechanism ?? this.mechanism,
        threadId: threadId ?? this.threadId,
      );
}
