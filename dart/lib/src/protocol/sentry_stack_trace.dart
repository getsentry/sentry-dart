import 'sentry_stack_frame.dart';

class SentryStackTrace {
  List<SentryStackFrame> _frames;

  List<SentryStackFrame> get frames => List.unmodifiable(_frames);

  set frames(List<SentryStackFrame> frames) {
    _frames = frames;
  }

  Map<String, String> _registers;

  Map<String, String> get registers => Map.unmodifiable(_registers);

  set registers(Map<String, String> registers) {
    _registers = registers;
  }

  Map<String, dynamic> toJson([String origin = '']) {
    final json = <String, dynamic>{};

    if (_frames?.isNotEmpty ?? false) {
      json['frames'] = _frames.map((frame) => frame.toJson(origin)).toList();
    }

    if (_registers?.isNotEmpty ?? false) {
      json['registers'] = _registers;
    }

    return json;
  }
}
