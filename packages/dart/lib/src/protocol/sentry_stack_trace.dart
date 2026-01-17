import 'package:meta/meta.dart';

import 'sentry_stack_frame.dart';
import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// Stacktrace holds information about the frames of the stack.
class SentryStackTrace {
  SentryStackTrace({
    required List<SentryStackFrame> frames,
    Map<String, String>? registers,
    this.lang,
    this.snapshot,
    this.unknown,
    @internal this.baseAddr,
    @internal this.buildId,
  })  : _frames = frames,
        _registers = Map.from(registers ?? {});

  List<SentryStackFrame>? _frames;

  /// Required. A non-empty immutable list of stack frames (see below).
  /// The list is ordered from caller to callee, or oldest to youngest.
  /// The last frame is the one creating the exception.
  List<SentryStackFrame> get frames => List.unmodifiable(_frames ?? const []);

  Map<String, String>? _registers;

  /// Optional. A map of register names and their values.
  /// The values should contain the actual register values of the thread,
  /// thus mapping to the last frame in the list.
  Map<String, String> get registers => Map.unmodifiable(_registers ?? const {});

  /// The language of the stacktrace
  String? lang;

  /// Indicates that this stack trace is a snapshot triggered
  /// by an external signal.
  ///
  /// If this field is false, then the stack trace points to the code that
  /// caused this stack trace to be created.
  /// This can be the location of a raised exception, as well as an exception or
  /// signal handler.
  ///
  /// If this field is true, then the stack trace was captured as part
  /// of creating an unrelated event. For example, a thread other than the
  /// crashing thread, or a stack trace computed as a result of an external kill
  /// signal.
  bool? snapshot;

  @internal
  String? baseAddr;

  @internal
  String? buildId;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryStackTrace] from JSON [Map].
  factory SentryStackTrace.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final framesJson = json.getValueOrNull<List<dynamic>>('frames');
    final registersJson = json.getValueOrNull<Map<String, dynamic>>('registers');
    return SentryStackTrace(
      frames: framesJson != null
          ? framesJson
              .map((frameJson) => SentryStackFrame.fromJson(
                  Map<String, dynamic>.from(frameJson as Map)))
              .toList()
          : [],
      registers: registersJson == null
          ? null
          : Map<String, String>.from(registersJson),
      lang: json.getValueOrNull('lang'),
      snapshot: json.getValueOrNull('snapshot'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (_frames?.isNotEmpty ?? false)
        'frames':
            _frames?.map((frame) => frame.toJson()).toList(growable: false),
      if (_registers?.isNotEmpty ?? false) 'registers': _registers,
      if (lang != null) 'lang': lang,
      if (snapshot != null) 'snapshot': snapshot,
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryStackTrace copyWith({
    List<SentryStackFrame>? frames,
    Map<String, String>? registers,
    String? lang,
    bool? snapshot,
  }) =>
      SentryStackTrace(
        frames: frames ?? this.frames,
        registers: registers ?? this.registers,
        lang: lang ?? this.lang,
        snapshot: snapshot ?? this.snapshot,
        unknown: unknown,
        baseAddr: baseAddr,
        buildId: buildId,
      );
}
