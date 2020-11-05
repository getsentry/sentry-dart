import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart';

import 'protocol/noop_origin.dart'
    if (dart.library.html) 'protocol/origin.dart';
import 'protocol/sentry_stack_frame.dart';
import 'sentry_options.dart';

/// converts [StackTrace] to [SentryStackFrames]
class SentryStackTraceFactory {
  /// A list of string prefixes of module names that do not belong to the app, but rather third-party
  /// packages. Modules considered not to be part of the app will be hidden from stack traces by
  /// default.
  final List<String> _inAppExcludes;

  /// A list of string prefixes of module names that belong to the app. This option takes precedence
  /// over inAppExcludes.
  final List<String> _inAppIncludes;

  SentryStackTraceFactory(SentryOptions options)
      : _inAppExcludes = options?.inAppExcludes,
        _inAppIncludes = options?.inAppIncludes;

  /// returns the [SentryStackFrame] list from a stackTrace ([StackTrace] or [String])
  List<SentryStackFrame> getStackFrames(dynamic stackTrace) {
    if (stackTrace == null) return null;

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

  /// converts [Frame] to [SentryStackFrame]
  @visibleForTesting
  SentryStackFrame encodeStackTraceFrame(Frame frame) {
    final fileName =
        frame.uri.pathSegments.isNotEmpty ? frame.uri.pathSegments.last : null;

    final sentryStackFrame = SentryStackFrame(
      absPath: '$eventOrigin${_absolutePathForCrashReport(frame)}',
      function: frame.member,
      lineNo: frame.line,
      colNo: frame.column,
      inApp: !frame.isCore /* TODO className != null ? isInApp(className) :*/,
      fileName: fileName,
      module: frame.library,
      package: frame.package,
      // TODO platform, postContext, preContext, rawFunction,
      // TODO ? native, frame, contextLine, framesOmitted, imageAddr,... ?
    );

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

  ///  Is the className InApp or not.
  bool isInApp(String className) {
    if (className == null || className.isEmpty) {
      return true;
    }

    if (_inAppIncludes != null) {
      for (final include in _inAppIncludes) {
        if (className.startsWith(include)) {
          return true;
        }
      }
    }
    if (_inAppExcludes != null) {
      for (final exclude in _inAppExcludes) {
        if (className.startsWith(exclude)) {
          return false;
        }
      }
    }
    return false;
  }
}
