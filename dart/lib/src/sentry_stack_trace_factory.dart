import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart';

import 'protocol/noop_origin.dart'
    if (dart.library.html) 'protocol/origin.dart';
import 'protocol.dart';
import 'sentry_options.dart';

/// converts [StackTrace] to [SentryStackFrames]
class SentryStackTraceFactory {
  SentryOptions _options;

  SentryStackTraceFactory(SentryOptions options) {
    if (options == null) {
      throw ArgumentError('SentryOptions is required.');
    }
    _options = options;
  }

  /// returns the [SentryStackFrame] list from a stackTrace ([StackTrace] or [String])
  List<SentryStackFrame> getStackFrames(dynamic stackTrace) {
    if (stackTrace == null) return null;

    final chain = (stackTrace is StackTrace)
        ? Chain.forTrace(stackTrace)
        : (stackTrace is String)
            ? Chain.parse(stackTrace)
            : Chain.parse('');

    // TODO: if strip symbols are enabled, thats what we see:
    // warning:  This VM has been configured to produce stack traces that violate the Dart standard.
    // ***       *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
    // unparsed  pid: 30930, tid: 30990, name 1.ui
    // unparsed  build_id: '5346e01103ffeed44e97094ff7bfcc19'
    // unparsed  isolate_dso_base: 723d447000, vm_dso_base: 723d447000
    // unparsed  isolate_instructions: 723d452000, vm_instructions: 723d449000
    // unparsed      #00 abs 000000723d6346d7 virt 00000000001ed6d7 _kDartIsolateSnapshotInstructions+0x1e26d7
    // unparsed      #01 abs 000000723d637527 virt 00000000001f0527 _kDartIsolateSnapshotInstructions+0x1e5527
    // unparsed      #02 abs 000000723d4a41a7 virt 000000000005d1a7 _kDartIsolateSnapshotInstructions+0x521a7
    // unparsed      #03 abs 000000723d624663 virt 00000000001dd663 _kDartIsolateSnapshotInstructions+0x1d2663
    // unparsed      #04 abs 000000723d4b8c3b virt 0000000000071c3b _kDartIsolateSnapshotInstructions+0x66c3b
    // unparsed      #05 abs 000000723d5ffe27 virt 00000000001b8e27 _kDartIsolateSna...

    // abs => instruction_addr
    // build_id => debug_images

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

    final abs = '$eventOrigin${_absolutePathForCrashReport(frame)}';

    var sentryStackFrame = SentryStackFrame(
      absPath: abs,
      function: frame.member,
      // https://docs.sentry.io/development/sdk-dev/features/#in-app-frames
      inApp: isInApp(frame),
      fileName: fileName,
      package: frame.package,
    );
    // platform: 'native' if strip symbols are enabled

    if (frame.line != null && frame.line >= 0) {
      sentryStackFrame = sentryStackFrame.copyWith(lineNo: frame.line);
    }

    if (frame.column != null && frame.column >= 0) {
      sentryStackFrame = sentryStackFrame.copyWith(colNo: frame.column);
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
    if (frame.uri.scheme != 'dart' &&
        frame.uri.scheme != 'package' &&
        frame.uri.pathSegments.isNotEmpty) {
      return frame.uri.pathSegments.last;
    }

    return '${frame.uri}';
  }

  /// whether this frame comes from the app and not from Dart core or 3rd party librairies
  bool isInApp(Frame frame) {
    final scheme = frame.uri.scheme;

    if (scheme == null || scheme.isEmpty) {
      return true;
    }

    if (_options.inAppIncludes != null) {
      for (final include in _options.inAppIncludes) {
        if (frame.package != null && frame.package.startsWith(include)) {
          return true;
        }
      }
    }
    if (_options.inAppExcludes != null) {
      for (final exclude in _options.inAppExcludes) {
        if (frame.package != null && frame.package.startsWith(exclude)) {
          return false;
        }
      }
    }

    if (frame.isCore || frame.uri.scheme == 'package') return false;

    return true;
  }
}
