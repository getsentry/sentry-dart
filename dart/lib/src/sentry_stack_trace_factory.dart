import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart';

import 'noop_origin.dart' if (dart.library.html) 'origin.dart';
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

    // TODO : fix : in release mode on Safari passing a stacktrace object fails, but works if it's passed as String
    final chain = (stackTrace is StackTrace)
        ? Chain.forTrace(stackTrace)
        : (stackTrace is String)
            ? Chain.parse(stackTrace)
            : Chain.parse('');

    final frames = <SentryStackFrame>[];
    var nativeStackTraces = false;

    for (final trace in chain.traces) {
      var hasFrames = false;

      for (final frame in trace.frames) {
        // we don't want to add our own frames
        if (frame.package == 'sentry') {
          continue;
        }

        final member = frame.member;
        // ideally the language would offer us a native way of parsing it.
        if (member != null &&
            member.contains(
              'This VM has been configured to produce stack traces that violate the Dart standard.',
            )) {
          nativeStackTraces = true;
        }

        final stackTraceFrame = encodeStackTraceFrame(
          frame,
          nativeStackTraces,
        );

        if (stackTraceFrame == null) {
          continue;
        }
        frames.add(stackTraceFrame);
        hasFrames = true;
      }

      // gap if stack trace has no frames
      if (!hasFrames) {
        frames.add(SentryStackFrame.asynchronousGapFrameJson);
      }
    }

    return frames.reversed.toList();
  }

  /// converts [Frame] to [SentryStackFrame]
  @visibleForTesting
  SentryStackFrame encodeStackTraceFrame(Frame frame, bool nativeStackTraces) {
    final member = frame.member;

    SentryStackFrame sentryStackFrame;

    if (!nativeStackTraces) {
      final fileName = frame.uri.pathSegments.isNotEmpty
          ? frame.uri.pathSegments.last
          : null;

      final abs = '$eventOrigin${_absolutePathForCrashReport(frame)}';

      sentryStackFrame = SentryStackFrame(
        absPath: abs,
        function: member,
        // https://docs.sentry.io/development/sdk-dev/features/#in-app-frames
        inApp: isInApp(frame),
        fileName: fileName,
        package: frame.package,
      );

      if (frame.line != null && frame.line >= 0) {
        sentryStackFrame = sentryStackFrame.copyWith(lineNo: frame.line);
      }

      if (frame.column != null && frame.column >= 0) {
        sentryStackFrame = sentryStackFrame.copyWith(colNo: frame.column);
      }
    } else {
      // if --split-debug-info is enabled, thats what we see:
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

      // we are only interested on the #01, 02... which contains the 'abs' addresses.
      if (member.contains('abs') && member.contains('virt')) {
        // TODO: use proper Regex, this works for now
        final indexAbs = member.indexOf('abs');
        final indexVirt = member.indexOf('virt');
        final instructionAddr =
            '0x${member.substring(indexAbs + 4, indexVirt - 1)}';

        sentryStackFrame = SentryStackFrame(
          instructionAddr: instructionAddr,
          platform: 'native', // to trigger symbolication
          symbolicated: false, // signal to load image list from Native SDKs
        );
      }
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
        if (frame.package != null && frame.package == include) {
          return true;
        }
      }
    }
    if (_options.inAppExcludes != null) {
      for (final exclude in _options.inAppExcludes) {
        if (frame.package != null && frame.package == exclude) {
          return false;
        }
      }
    }

    if (frame.isCore ||
        (frame.uri.scheme == 'package' && frame.package == 'flutter')) {
      return false;
    }

    return true;
  }
}
