import 'package:meta/meta.dart';

import '../protocol.dart';
import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// The Exception Interface specifies an exception or error that occurred in a program.
class SentryException {
  /// Required. The type of exception
  String? type;

  /// Required. The value of the exception
  String? value;

  /// The optional module, or package which the exception type lives in.
  String? module;

  /// An optional stack trace object
  SentryStackTrace? stackTrace;

  /// An optional object describing the [Mechanism] that created this exception
  Mechanism? mechanism;

  /// Represents a [SentryThread.id].
  int? threadId;

  dynamic throwable;

  @internal
  Map<String, dynamic>? unknown;

  List<SentryException>? _exceptions;

  SentryException({
    required this.type,
    required this.value,
    this.module,
    this.stackTrace,
    this.mechanism,
    this.threadId,
    this.throwable,
    this.unknown,
  });

  /// Deserializes a [SentryException] from JSON [Map].
  factory SentryException.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);

    final stackTraceJson =
        json.getValueOrNull<Map<String, dynamic>>('stacktrace');
    final mechanismJson =
        json.getValueOrNull<Map<String, dynamic>>('mechanism');
    return SentryException(
      type: json.getValueOrNull('type')!,
      value: json.getValueOrNull('value')!,
      module: json.getValueOrNull('module'),
      stackTrace: stackTraceJson != null
          ? SentryStackTrace.fromJson(
              Map<String, dynamic>.from(stackTraceJson),
            )
          : null,
      mechanism: mechanismJson != null
          ? Mechanism.fromJson(Map<String, dynamic>.from(mechanismJson))
          : null,
      threadId: json.getValueOrNull('thread_id'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (type != null) 'type': type,
      if (value != null) 'value': value,
      if (module != null) 'module': module,
      if (stackTrace != null) 'stacktrace': stackTrace!.toJson(),
      if (mechanism != null) 'mechanism': mechanism!.toJson(),
      if (threadId != null) 'thread_id': threadId,
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryException copyWith({
    String? type,
    String? value,
    String? module,
    SentryStackTrace? stackTrace,
    Mechanism? mechanism,
    int? threadId,
    dynamic throwable,
  }) =>
      SentryException(
        type: type ?? this.type,
        value: value ?? this.value,
        module: module ?? this.module,
        stackTrace: stackTrace ?? this.stackTrace?.copyWith(),
        mechanism: mechanism ?? this.mechanism?.copyWith(),
        threadId: threadId ?? this.threadId,
        throwable: throwable ?? this.throwable,
        unknown: unknown,
      );

  @internal
  List<SentryException>? get exceptions =>
      _exceptions != null ? List.unmodifiable(_exceptions!) : null;

  @internal
  set exceptions(List<SentryException>? value) {
    _exceptions = value;
  }

  @internal
  void addException(SentryException exception) {
    _exceptions ??= [];
    _exceptions!.add(exception);
  }
}
