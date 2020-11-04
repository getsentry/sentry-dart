import 'sentry_stack_frame.dart';

class SentryStackTrace {
  const SentryStackTrace({
    List<SentryStackFrame> frames,
    Map<String, String> registers,
  })  : _frames = frames,
        _registers = registers;

  final List<SentryStackFrame> _frames;

  List<SentryStackFrame> get frames => List.unmodifiable(_frames);

  final Map<String, String> _registers;

  Map<String, String> get registers => Map.unmodifiable(_registers);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (_frames?.isNotEmpty ?? false) {
      json['frames'] = _frames.map((frame) => frame.toJson()).toList();
    }

    if (_registers?.isNotEmpty ?? false) {
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
