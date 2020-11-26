import 'package:meta/meta.dart';

import 'sentry_stack_frame.dart';

/// Stacktrace holds information about the frames of the stack.
class SentryStackTrace {
  const SentryStackTrace({
    @required List<SentryStackFrame> frames,
    Map<String, String> registers,
  })  : _frames = frames,
        _registers = registers;

  final List<SentryStackFrame> _frames;

  /// Required. A non-empty list of stack frames (see below).
  /// The list is ordered from caller to callee, or oldest to youngest.
  /// The last frame is the one creating the exception.
  List<SentryStackFrame> get frames => List.unmodifiable(_frames);

  final Map<String, String> _registers;

  /// Optional. A map of register names and their values.
  /// The values should contain the actual register values of the thread,
  /// thus mapping to the last frame in the list.
  Map<String, String> get registers => Map.unmodifiable(_registers);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (_frames != null && _frames.isNotEmpty) {
      json['frames'] = _frames.map((frame) => frame.toJson()).toList(growable: false);
    }

    if (_registers != null && _registers.isNotEmpty ?? false) {
      json['registers'] = _registers;
    }

    return json;
  }

  SentryStackTrace copyWith({
    List<SentryStackFrame> frames,
    Map<String, String> registers,
  }) =>
      SentryStackTrace(
        frames: frames ?? this.frames,
        registers: registers ?? this.registers,
      );
}
