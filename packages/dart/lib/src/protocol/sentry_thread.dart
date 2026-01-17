import 'package:meta/meta.dart';

import 'sentry_stack_trace.dart';
import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// The Threads Interface specifies threads that were running at the time an
/// event happened. These threads can also contain stack traces.
/// See https://develop.sentry.dev/sdk/event-payloads/threads/
class SentryThread {
  SentryThread({
    this.id,
    this.name,
    this.crashed,
    this.current,
    this.stacktrace,
    this.unknown,
  });

  factory SentryThread.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final stacktraceJson =
        json.getValueOrNull<Map<String, dynamic>>('stacktrace');
    return SentryThread(
      id: json.getValueOrNull('id'),
      name: json.getValueOrNull('name'),
      crashed: json.getValueOrNull('crashed'),
      current: json.getValueOrNull('current'),
      stacktrace: stacktraceJson == null
          ? null
          : SentryStackTrace.fromJson(
              Map<String, dynamic>.from(stacktraceJson),
            ),
      unknown: json.notAccessed(),
    );
  }

  /// The Id of the thread.
  int? id;

  /// The name of the thread.
  /// On Dart platforms where Isolates are available, this can be set to
  /// [Isolate.debugName](https://api.flutter.dev/flutter/dart-isolate/Isolate/debugName.html)
  String? name;

  /// Whether the crash happened on this thread.
  bool? crashed;

  /// An optional flag to indicate that the thread was in the foreground.
  bool? current;

  /// Stack trace.
  /// See https://develop.sentry.dev/sdk/event-payloads/stacktrace/
  SentryStackTrace? stacktrace;

  @internal
  final Map<String, dynamic>? unknown;

  Map<String, dynamic> toJson() {
    final stacktrace = this.stacktrace;
    return {
      ...?unknown,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (crashed != null) 'crashed': crashed,
      if (current != null) 'current': current,
      if (stacktrace != null) 'stacktrace': stacktrace.toJson(),
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryThread copyWith({
    int? id,
    String? name,
    bool? crashed,
    bool? current,
    SentryStackTrace? stacktrace,
  }) {
    return SentryThread(
      id: id ?? this.id,
      name: name ?? this.name,
      crashed: crashed ?? this.crashed,
      current: current ?? this.current,
      stacktrace: stacktrace ?? this.stacktrace,
      unknown: unknown,
    );
  }
}
