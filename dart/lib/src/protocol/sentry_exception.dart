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

  /// Represents a [SentryThread.id].
  final int? threadId;

  const SentryException({
    required this.type,
    required this.value,
    this.module,
    this.stackTrace,
    this.mechanism,
    this.threadId,
  });

  /// Deserializes a [SentryException] from JSON [Map].
  factory SentryException.fromJson(Map<String, dynamic> json) {
    final stackTraceJson = json['stacktrace'];
    final mechanismJson = json['mechanism'];
    return SentryException(
      type: json['type'],
      value: json['value'],
      module: json['module'],
      stackTrace: stackTraceJson != null
          ? SentryStackTrace.fromJson(stackTraceJson)
          : null,
      mechanism:
          mechanismJson != null ? Mechanism.fromJson(mechanismJson) : null,
      threadId: json['thread_id'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (module != null) 'module': module,
      if (stackTrace != null) 'stacktrace': stackTrace!.toJson(),
      if (mechanism != null) 'mechanism': mechanism!.toJson(),
      if (threadId != null) 'thread_id': threadId,
    };
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
