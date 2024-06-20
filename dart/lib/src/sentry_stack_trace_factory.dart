import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart';

import 'origin.dart';
import 'protocol.dart';
import 'sentry_options.dart';

/// converts [StackTrace] to [SentryStackFrame]s
class SentryStackTraceFactory {
  final SentryOptions _options;

  final _absRegex = RegExp(r'^\s*#[0-9]+ +abs +([A-Fa-f0-9]+)');
  final _frameRegex = RegExp(r'^\s*#', multiLine: true);

  static final SentryStackFrame _asynchronousGapFrameJson =
      SentryStackFrame(absPath: '<asynchronous suspension>');

  SentryStackTraceFactory(this._options);

  /// returns the [SentryStackFrame] list from a stackTrace ([StackTrace] or [String])
  List<SentryStackFrame> getStackFrames(dynamic stackTrace) {
    final chain = _parseStackTrace(stackTrace);
    final frames = <SentryStackFrame>[];
    var onlyAsyncGap = true;

    for (var t = 0; t < chain.traces.length; t += 1) {
      final trace = chain.traces[t];

      // NOTE: We want to keep the Sentry frames for crash detection
      // this does not affect grouping since they're not marked as inApp
      for (final frame in trace.frames) {
        final stackTraceFrame = encodeStackTraceFrame(frame);
        if (stackTraceFrame != null) {
          frames.add(stackTraceFrame);
          onlyAsyncGap = false;
        }
      }

      // fill asynchronous gap
      if (t < chain.traces.length - 1) {
        frames.add(_asynchronousGapFrameJson);
      }
    }

    return onlyAsyncGap ? [] : frames.reversed.toList();
  }

  Chain _parseStackTrace(dynamic stackTrace) {
    if (stackTrace is Chain || stackTrace is Trace) {
      return Chain.forTrace(stackTrace);
    }

    // We need to convert to string and split the headers manually, otherwise
    // they end up in the final stack trace as "unparsed" lines.
    // Note: [Chain.forTrace] would call [stackTrace.toString()] too.
    if (stackTrace is StackTrace) {
      stackTrace = stackTrace.toString();
    }

    if (stackTrace is String) {
      // Remove headers (everything before the first line starting with '#').
      // *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
      // pid: 19226, tid: 6103134208, name io.flutter.ui
      // os: macos arch: arm64 comp: no sim: no
      // isolate_dso_base: 10fa20000, vm_dso_base: 10fa20000
      // isolate_instructions: 10fa27070, vm_instructions: 10fa21e20
      //     #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
      //     #01 abs 000000723d637527 _kDartIsolateSnapshotInstructions+0x1e5527

      final startOffset = _frameRegex.firstMatch(stackTrace)?.start ?? 0;
      return Chain.parse(
          startOffset == 0 ? stackTrace : stackTrace.substring(startOffset));
    }
    return Chain([]);
  }

  /// converts [Frame] to [SentryStackFrame]
  @visibleForTesting
  SentryStackFrame? encodeStackTraceFrame(Frame frame) {
    final member = frame.member;

    if (frame is UnparsedFrame && member != null) {
      // if --split-debug-info is enabled, thats what we see:
      // *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
      // pid: 19226, tid: 6103134208, name io.flutter.ui
      // os: macos arch: arm64 comp: no sim: no
      // isolate_dso_base: 10fa20000, vm_dso_base: 10fa20000
      // isolate_instructions: 10fa27070, vm_instructions: 10fa21e20
      //     #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
      //     #01 abs 000000723d637527 _kDartIsolateSnapshotInstructions+0x1e5527

      // we are only interested on the #01, 02... items which contains the 'abs' addresses.
      final match = _absRegex.firstMatch(member);
      if (match != null) {
        return SentryStackFrame(
          instructionAddr: '0x${match.group(1)!}',
          platform: 'native', // to trigger symbolication & native LoadImageList
        );
      }

      // We shouldn't get here. If we do, it means there's likely an issue in
      // the parsing so let's fall back and post a stack trace as is, so that at
      // least we get an indication something's wrong and are able to fix it.
    }

    final fileName =
        frame.uri.pathSegments.isNotEmpty ? frame.uri.pathSegments.last : null;
    final abs = '$eventOrigin${_absolutePathForCrashReport(frame)}';

    var sentryStackFrame = SentryStackFrame(
      absPath: abs,
      function: member,
      // https://docs.sentry.io/development/sdk-dev/features/#in-app-frames
      inApp: _isInApp(frame),
      fileName: fileName,
      package: frame.package,
    );

    final line = frame.line;
    if (line != null && line >= 0) {
      sentryStackFrame = sentryStackFrame.copyWith(lineNo: frame.line);
    }

    final column = frame.column;
    if (column != null && column >= 0) {
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

    return frame.uri.toString();
  }

  /// whether this frame comes from the app and not from Dart core or 3rd party librairies
  bool _isInApp(Frame frame) {
    final scheme = frame.uri.scheme;

    if (scheme.isEmpty) {
      // Early bail out.
      return _options.considerInAppFramesByDefault;
    }
    // The following code depends on the scheme being set.

    final package = frame.package;
    if (package != null) {
      if (_options.inAppIncludes.contains(package)) {
        return true;
      }

      if (_options.inAppExcludes.contains(package)) {
        return false;
      }
    }

    if (frame.isCore) {
      // This is a Dart frame
      return false;
    }

    if (frame.package == 'flutter') {
      // This is a Flutter frame
      return false;
    }

    return _options.considerInAppFramesByDefault;
  }
}
