import 'package:meta/meta.dart';
import 'access_aware_map.dart';

/// Frames belong to a StackTrace
/// It should contain at least a filename, function or instruction_addr
class SentryStackFrame {
  SentryStackFrame({
    this.absPath,
    this.fileName,
    this.function,
    this.module,
    this.lineNo,
    this.colNo,
    this.contextLine,
    this.inApp,
    this.package,
    this.native,
    this.platform,
    this.imageAddr,
    this.symbolAddr,
    this.instructionAddr,
    this.rawFunction,
    this.stackStart,
    this.symbol,
    List<int>? framesOmitted,
    List<String>? preContext,
    List<String>? postContext,
    Map<String, dynamic>? vars,
    this.unknown,
  }) : _framesOmitted = framesOmitted != null ? List.from(framesOmitted) : null,
       _preContext = preContext != null ? List.from(preContext) : null,
       _postContext = postContext != null ? List.from(postContext) : null,
       _vars = vars != null ? Map.from(vars) : null;

  /// The absolute path to filename.
  String? absPath;

  List<String>? _preContext;

  /// An immutable list of source code lines before context_line (in order) – usually `lineno - 5:lineno`.
  List<String> get preContext => List.unmodifiable(_preContext ?? const []);

  List<String>? _postContext;

  /// An immutable list of source code lines after context_line (in order) – usually `lineno + 1:lineno + 5`.
  List<String> get postContext => List.unmodifiable(_postContext ?? const []);

  Map<String, dynamic>? _vars;

  /// An immutable mapping of variables which were available within this frame (usually context-locals).
  Map<String, dynamic> get vars => Map.unmodifiable(_vars ?? const {});

  List<int>? _framesOmitted;

  /// Which frames were omitted, if any.
  ///
  /// If the list of frames is large, you can explicitly tell the system
  /// that you’ve omitted a range of frames.
  /// The frames_omitted must be a single tuple two values: start and end.
  //
  /// Example : If you only removed the 8th frame, the value would be (8, 9),
  /// meaning it started at the 8th frame, and went until the 9th (the number of frames omitted is end-start).
  /// The values should be based on a one-index.
  List<int> get framesOmitted => List.unmodifiable(_framesOmitted ?? const []);

  /// The relative file path to the call.
  String? fileName;

  /// The name of the function being called.
  String? function;

  /// Platform-specific module path.
  String? module;

  /// The column number of the call
  int? lineNo;

  /// The column number of the call
  int? colNo;

  /// Source code in filename at line number.
  String? contextLine;

  /// Signifies whether this frame is related to the execution of the relevant code in this stacktrace.
  ///
  /// For example, the frames that might power the framework’s web server of your app are probably not relevant, however calls to the framework’s library once you start handling code likely are.
  bool? inApp;

  /// The "package" the frame was contained in.
  String? package;

  // TODO what is this? doesn't seem to be part of the spec https://develop.sentry.dev/sdk/event-payloads/stacktrace/
  bool? native;

  /// This can override the platform for a single frame. Otherwise, the platform of the event is assumed. This can be used for multi-platform stack traces
  String? platform;

  /// Optionally an address of the debug image to reference.
  String? imageAddr;

  /// An optional address that points to a symbol. We use the instruction address for symbolication, but this can be used to calculate an instruction offset automatically.
  String? symbolAddr;

  /// The instruction address
  /// The official docs refer to it as 'The difference between instruction address and symbol address in bytes.'
  String? instructionAddr;

  /// The original function name, if the function name is shortened or demangled. Sentry shows the raw function when clicking on the shortened one in the UI.
  String? rawFunction;

  /// Marks this frame as the bottom of a chained stack trace.
  ///
  /// Stack traces from asynchronous code consist of several sub traces that
  /// are chained together into one large list. This flag indicates the root
  /// function of a chained stack trace. Depending on the runtime and thread,
  /// this is either the main function or a thread base stub.
  ///
  /// This field should only be specified when true.
  bool? stackStart;

  /// Potentially mangled name of the symbol as it appears in an executable.
  ///
  /// This is different from a function name by generally being the mangled name
  /// that appears natively in the binary.
  /// This is relevant for languages like Swift, C++ or Rust.
  String? symbol;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryStackFrame] from JSON [Map].
  factory SentryStackFrame.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryStackFrame(
      absPath: json.readString('abs_path'),
      fileName: json.readString('filename'),
      function: json.readString('function'),
      module: json.readString('module'),
      lineNo: json.readInt('lineno'),
      colNo: json.readInt('colno'),
      contextLine: json.readString('context_line'),
      inApp: json.readBool('in_app'),
      package: json.readString('package'),
      native: json.readBool('native'),
      platform: json.readString('platform'),
      imageAddr: json.readString('image_addr'),
      symbolAddr: json.readString('symbol_addr'),
      instructionAddr: json.readString('instruction_addr'),
      rawFunction: json.readString('raw_function'),
      framesOmitted: json.readIntList('frames_omitted'),
      preContext: json.readStringList('pre_context'),
      postContext: json.readStringList('post_context'),
      vars: json.readMap('vars'),
      symbol: json.readString('symbol'),
      stackStart: json.readBool('stack_start'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (_preContext?.isNotEmpty ?? false) 'pre_context': _preContext,
      if (_postContext?.isNotEmpty ?? false) 'post_context': _postContext,
      if (_vars?.isNotEmpty ?? false) 'vars': _vars,
      if (_framesOmitted?.isNotEmpty ?? false) 'frames_omitted': _framesOmitted,
      'filename': ?fileName,
      'package': ?package,
      'function': ?function,
      'module': ?module,
      'lineno': ?lineNo,
      'colno': ?colNo,
      'abs_path': ?absPath,
      'context_line': ?contextLine,
      'in_app': ?inApp,
      'native': ?native,
      'platform': ?platform,
      'image_addr': ?imageAddr,
      'symbol_addr': ?symbolAddr,
      'instruction_addr': ?instructionAddr,
      'raw_function': ?rawFunction,
      'symbol': ?symbol,
      'stack_start': ?stackStart,
    };
  }
}
