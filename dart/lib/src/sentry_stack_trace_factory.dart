import 'package:stack_trace/stack_trace.dart';

import 'protocol/sentry_stack_frame.dart';

class SentryStackTraceFactory {
  List<SentryStackFrame> getStackFrames(dynamic stackTrace) {
    final chain = stackTrace is StackTrace
        ? Chain.forTrace(stackTrace)
        : Chain.parse(stackTrace as String);

    final frames = <SentryStackFrame>[];
    for (var t = 0; t < chain.traces.length; t += 1) {
      final encodedFrames =
          chain.traces[t].frames.map((f) => encodeStackTraceFrame(f));

      frames.addAll(encodedFrames);

      if (t < chain.traces.length - 1) {
        frames.add(SentryStackFrame.asynchronousGapFrameJson);
      }
    }

    return frames.reversed.toList();
  }

  SentryStackFrame encodeStackTraceFrame(Frame frame) {
    final sentryStackFrame = SentryStackFrame()
      // TODO add the origin to absPath before sending
      ..absPath = '${_absolutePathForCrashReport(frame)}'
      ..function = frame.member
      ..lineno = '${frame.line}'
      ..colno = '${frame.column}'
      ..inApp = !frame.isCore;

    if (frame.uri.pathSegments.isNotEmpty) {
      sentryStackFrame.filename = frame.uri.pathSegments.last;
    }

    return sentryStackFrame;
  }

  /// A stack frame's code path may be one of "file:", "dart:" and "package:".
  ///
  /// Absolute file paths may contain personally identifiable information, and
  /// therefore are stripped to only send the base file name. For example,
  /// "/foo/bar/baz.dart" is reported as "baz.dart".
  ///
  /// "dart:" and "package:" imports are always relative and are OK to send in
  /// full.
  String _absolutePathForCrashReport(Frame frame) {
    if (frame.uri.scheme != 'dart' && frame.uri.scheme != 'package') {
      return frame.uri.pathSegments.last;
    }

    return '${frame.uri}';
  }
}
