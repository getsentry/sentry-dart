import 'package:meta/meta.dart';
import 'package:stack_trace/stack_trace.dart';

import 'origin.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'utils/stacktrace_utils.dart';

/// converts [StackTrace] to [SentryStackFrame]s
class SentryStackTraceFactory {
  final SentryOptions _options;

  static final _frameRegex = RegExp(r'^\s*#', multiLine: true);
  static final _baseAddrRegex = RegExp(r'isolate_dso_base[:=] *([A-Fa-f0-9]+)');
  static final SentryStackFrame _asynchronousGapFrameJson =
      SentryStackFrame(absPath: '<asynchronous suspension>');

  SentryStackTraceFactory(this._options);

  /// returns the [SentryStackFrame] list from a stackTrace ([StackTrace] or [String])
  @Deprecated('Use parse() instead')
  List<SentryStackFrame> getStackFrames(dynamic stackTrace) {
    return parse(stackTrace).frames;
  }

  SentryStackTrace parse(dynamic stackTrace, {bool? removeSentryFrames}) {
    final parsed = _parseStackTrace(stackTrace);
    final frames = <SentryStackFrame>[];
    var onlyAsyncGap = true;

    for (var t = 0; t < parsed.traces.length; t += 1) {
      final trace = parsed.traces[t];

      // NOTE: We want to keep the Sentry frames for SDK crash detection
      // this does not affect grouping since they're not marked as inApp
      // only exception if there was no stack trace, we remove them
      for (final frame in trace.frames) {
        var stackTraceFrame = encodeStackTraceFrame(frame);

        if (stackTraceFrame != null) {
          if (removeSentryFrames == true &&
              (stackTraceFrame.package == 'sentry' ||
                  stackTraceFrame.package == 'sentry_flutter')) {
            continue;
          }
          frames.add(stackTraceFrame);
          onlyAsyncGap = false;
        }
      }

      // fill asynchronous gap
      if (t < parsed.traces.length - 1) {
        frames.add(_asynchronousGapFrameJson);
      }
    }

    return SentryStackTrace(
      frames: onlyAsyncGap ? [] : frames.reversed.toList(),
      baseAddr: parsed.baseAddr,
      buildId: parsed.buildId,
    );
  }

  // `package:stack_trace`'s V8 trace parser unconditionally treats the
  // first line as an exception-message header and skips it. dart2wasm's
  // `StackTrace.toString()` - unlike a real V8 JS error - never includes
  // that header, so the parser silently drops the first (often only) real
  // frame. Detect that shape and prepend a synthetic header line to absorb
  // the skip instead.
  static final _v8FrameLineStart = RegExp(r'^\s{0,4}at ');

  String _ensureV8MessageHeader(String stackTrace) {
    final firstNewline = stackTrace.indexOf('\n');
    final firstLine =
        firstNewline == -1 ? stackTrace : stackTrace.substring(0, firstNewline);
    if (_v8FrameLineStart.hasMatch(firstLine)) {
      return '\n$stackTrace';
    }
    return stackTrace;
  }

  _StackInfo _parseStackTrace(dynamic stackTrace) {
    if (stackTrace is Chain) {
      return _StackInfo(stackTrace.traces);
    } else if (stackTrace is Trace) {
      return _StackInfo([stackTrace]);
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
      // build_id: 'bca64abfdfcc84d231bb8f1ccdbfbd8d'
      // isolate_dso_base: 10fa20000, vm_dso_base: 10fa20000
      // isolate_instructions: 10fa27070, vm_instructions: 10fa21e20
      //     #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7
      //     #01 abs 000000723d637527 _kDartIsolateSnapshotInstructions+0x1e5527

      final startOffset = _frameRegex.firstMatch(stackTrace)?.start ?? 0;
      final trimmed =
          startOffset == 0 ? stackTrace : stackTrace.substring(startOffset);
      final chain = Chain.parse(_ensureV8MessageHeader(trimmed));
      final info = _StackInfo(chain.traces);
      info.buildId = buildIdRegex.firstMatch(stackTrace)?.group(1);
      info.baseAddr = _baseAddrRegex.firstMatch(stackTrace)?.group(1);
      if (info.baseAddr != null) {
        info.baseAddr = '0x${info.baseAddr}';
      }
      return info;
    }
    return _StackInfo([]);
  }

  // DDC (`flutter run -d chrome`) serves every pub package's sources under
  // this path prefix - there's no `package:` scheme on web, so this is the
  // only signal available to recover the package name.
  static final _webPackagePath = RegExp(r'(?:^|/)packages/([^/]+)/(.+)$');

  // DDC also serves the Dart SDK sources it's compiled against under this
  // path prefix.
  static final _webSdkPath = RegExp(r'(?:^|/)dart-sdk/lib/(.+)$');

  /// Rewrites a DDC-served web frame's URI back into the `package:`/`dart:`
  /// shape [_isInApp] and [_absolutePathForCrashReport] already understand.
  /// No-op for anything that isn't a recognized DDC path (in particular,
  /// release/profile web builds, where app and dependency code share a
  /// single bundle URL with no per-frame signal to recover).
  Frame _normalizeWebFrame(Frame frame) {
    final uri = frame.uri;
    if (uri.scheme == 'package' || uri.scheme == 'dart') {
      return frame;
    }

    final packageMatch = _webPackagePath.firstMatch(uri.path);
    if (packageMatch != null) {
      return Frame(
        Uri.parse('package:${packageMatch.group(1)}/${packageMatch.group(2)}'),
        frame.line,
        frame.column,
        frame.member,
      );
    }

    final sdkMatch = _webSdkPath.firstMatch(uri.path);
    if (sdkMatch != null) {
      return Frame(
        Uri.parse('dart:${sdkMatch.group(1)}'),
        frame.line,
        frame.column,
        frame.member,
      );
    }

    return frame;
  }

  /// converts [Frame] to [SentryStackFrame]
  @visibleForTesting
  SentryStackFrame? encodeStackTraceFrame(Frame originalFrame) {
    final frame = _options.platform.isWeb
        ? _normalizeWebFrame(originalFrame)
        : originalFrame;
    final member = frame.member;

    if (frame is UnparsedFrame && member != null) {
      // if --split-debug-info is enabled, that's what we see:
      //     #00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7

      // we are only interested on the #01, 02... items which contains the 'abs' addresses.
      final match = absRegex.firstMatch(member);
      if (match != null) {
        return SentryStackFrame(
          instructionAddr: '0x${match.group(1)!}',
          // 'native' triggers the [LoadImageListIntegration] and server-side symbolication
          platform: 'native',
        );
      }

      // We shouldn't get here. If we do, it means there's likely an issue in
      // the parsing so let's fall back and post a stack trace as is, so that at
      // least we get an indication something's wrong and are able to fix it.
      _options.log(SentryLevel.debug, "Failed to parse stack frame: $member");
    }

    final platform = _options.platform.isWeb ? 'javascript' : 'dart';
    final fileName =
        frame.uri.pathSegments.isNotEmpty ? frame.uri.pathSegments.last : null;
    final abs = '$eventOrigin${_absolutePathForCrashReport(frame)}';

    final includeModule =
        frame.package != null && _options.includeModuleInStackTrace;

    var sentryStackFrame = SentryStackFrame(
      absPath: abs,
      function: member,
      // https://docs.sentry.io/development/sdk-dev/features/#in-app-frames
      inApp: _isInApp(frame),
      fileName: fileName,
      package: frame.package,
      platform: platform,
      module: includeModule
          ? frame.uri.pathSegments
              .sublist(0, frame.uri.pathSegments.length - 1)
              .join('/')
          : null,
    );

    final line = frame.line;
    if (line != null && line >= 0) {
      sentryStackFrame.lineNo = frame.line;
    }

    final column = frame.column;
    if (column != null && column >= 0) {
      sentryStackFrame.colNo = frame.column;
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

    if (_options.platform.isWeb && _isKnownNonAppWebAsset(frame)) {
      return false;
    }

    return _options.considerInAppFramesByDefault;
  }

  // Bundled Flutter/engine web assets that never carry app code. In release
  // and profile web builds, app code and every pub dependency are compiled
  // into a single JS/wasm bundle with no per-frame signal to separate them -
  // this denylist is the honest ceiling of what's classifiable client-side
  // in that mode.
  static const _nonAppWebAssets = {
    'flutter.js',
    'flutter_bootstrap.js',
    'flutter_service_worker.js',
    'canvaskit.js',
    'skwasm.js',
    'skwasm_st.js',
    'skwasm_heavy.js',
    'dart_sdk.js',
  };

  bool _isKnownNonAppWebAsset(Frame frame) {
    final segments = frame.uri.pathSegments;
    final fileName = segments.isEmpty ? '' : segments.last;
    return _nonAppWebAssets.contains(fileName);
  }
}

class _StackInfo {
  String? baseAddr;
  String? buildId;
  final List<Trace> traces;

  _StackInfo(this.traces);
}
