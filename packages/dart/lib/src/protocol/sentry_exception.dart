import 'package:meta/meta.dart';

import '../protocol.dart';
import 'access_aware_map.dart';

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
  factory SentryException.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);
    return SentryException(
      type: json.readString('type'),
      value: json.readString('value'),
      module: json.readString('module'),
      stackTrace: json.readObject('stacktrace', SentryStackTrace.fromJson),
      mechanism: json.readObject('mechanism', Mechanism.fromJson),
      threadId: json.readInt('thread_id'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'type': ?type,
      'value': ?value,
      'module': ?module,
      'stacktrace': ?stackTrace?.toJson(),
      'mechanism': ?mechanism?.toJson(),
      'thread_id': ?threadId,
    };
  }

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
