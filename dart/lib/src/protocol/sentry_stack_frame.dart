import 'package:meta/meta.dart';

/// Frames belong to a StackTrace
/// It should contain at least a filename, function or instruction_addr
@immutable
class SentryStackFrame {
  static final SentryStackFrame asynchronousGapFrameJson =
      SentryStackFrame(absPath: '<asynchronous suspension>');

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
    List<int>? framesOmitted,
    List<String>? preContext,
    List<String>? postContext,
    Map<String, String>? vars,
  })  : _framesOmitted =
            framesOmitted != null ? List.from(framesOmitted) : null,
        _preContext = preContext != null ? List.from(preContext) : null,
        _postContext = postContext != null ? List.from(postContext) : null,
        _vars = vars != null ? Map.from(vars) : null;

  /// The absolute path to filename.
  final String? absPath;

  final List<String>? _preContext;

  /// An immutable list of source code lines before context_line (in order) – usually [lineno - 5:lineno].
  List<String> get preContext => List.unmodifiable(_preContext ?? const []);

  final List<String>? _postContext;

  /// An immutable list of source code lines after context_line (in order) – usually [lineno + 1:lineno + 5].
  List<String> get postContext => List.unmodifiable(_postContext ?? const []);

  final Map<String, String>? _vars;

  /// An immutable mapping of variables which were available within this frame (usually context-locals).
  Map<String, String> get vars => Map.unmodifiable(_vars ?? const {});

  final List<int>? _framesOmitted;

  /// Which frames were omitted, if any.
  ///
  /// If the list of frames is large, you can explicitly tell the system
  /// that you’ve omitted a range of frames.
  /// The frames_omitted must be a single tuple two values: start and end.
  //
  /// Example : If you only removed the 8th frame, the value would be (8, 9),
  /// meaning it started at the 8th frame, and went untilthe 9th (the number of frames omitted is end-start).
  /// The values should be based on a one-index.
  List<int> get framesOmitted => List.unmodifiable(_framesOmitted ?? const []);

  /// The relative file path to the call.
  final String? fileName;

  /// The name of the function being called.
  final String? function;

  /// Platform-specific module path.
  final String? module;

  /// The column number of the call
  final int? lineNo;

  /// The column number of the call
  final int? colNo;

  /// Source code in filename at line number.
  final String? contextLine;

  /// Signifies whether this frame is related to the execution of the relevant code in this stacktrace.
  ///
  /// For example, the frames that might power the framework’s web server of your app are probably not relevant, however calls to the framework’s library once you start handling code likely are.
  final bool? inApp;

  /// The "package" the frame was contained in.
  final String? package;

  final bool? native;

  /// This can override the platform for a single frame. Otherwise, the platform of the event is assumed. This can be used for multi-platform stack traces
  final String? platform;

  /// Optionally an address of the debug image to reference.
  final String? imageAddr;

  /// An optional address that points to a symbol. We use the instruction address for symbolication, but this can be used to calculate an instruction offset automatically.
  final String? symbolAddr;

  /// The instruction address
  /// The official docs refer to it as 'The difference between instruction address and symbol address in bytes.'
  final String? instructionAddr;

  /// The original function name, if the function name is shortened or demangled. Sentry shows the raw function when clicking on the shortened one in the UI.
  final String? rawFunction;

  /// Deserializes a [SentryStackFrame] from JSON [Map].
  factory SentryStackFrame.fromJson(Map<String, dynamic> json) {
    return SentryStackFrame(
      absPath: json['abs_path'],
      fileName: json['filename'],
      function: json['function'],
      module: json['module'],
      lineNo: json['lineno'],
      colNo: json['colno'],
      contextLine: json['context_line'],
      inApp: json['in_app'],
      package: json['package'],
      native: json['native'],
      platform: json['platform'],
      imageAddr: json['image_addr'],
      symbolAddr: json['symbol_addr'],
      instructionAddr: json['instruction_addr'],
      rawFunction: json['raw_function'],
      framesOmitted: json['frames_omitted'],
      preContext: json['pre_context'],
      postContext: json['post_context'],
      vars: json['vars'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (_preContext?.isNotEmpty ?? false) {
      json['pre_context'] = _preContext;
    }

    if (_postContext?.isNotEmpty ?? false) {
      json['post_context'] = _postContext;
    }

    if (_vars?.isNotEmpty ?? false) {
      json['vars'] = _vars;
    }

    if (_framesOmitted?.isNotEmpty ?? false) {
      json['frames_omitted'] = _framesOmitted;
    }

    if (fileName != null) {
      json['filename'] = fileName;
    }

    if (package != null) {
      json['package'] = package;
    }

    if (function != null) {
      json['function'] = function;
    }

    if (module != null) {
      json['module'] = module;
    }

    if (lineNo != null) {
      json['lineno'] = lineNo;
    }

    if (colNo != null) {
      json['colno'] = colNo;
    }

    if (absPath != null) {
      json['abs_path'] = absPath;
    }

    if (contextLine != null) {
      json['context_line'] = contextLine;
    }

    if (inApp != null) {
      json['in_app'] = inApp;
    }

    if (native != null) {
      json['native'] = native;
    }

    if (platform != null) {
      json['platform'] = platform;
    }

    if (imageAddr != null) {
      json['image_addr'] = imageAddr;
    }

    if (symbolAddr != null) {
      json['symbol_addr'] = symbolAddr;
    }

    if (instructionAddr != null) {
      json['instruction_addr'] = instructionAddr;
    }

    if (rawFunction != null) {
      json['raw_function'] = rawFunction;
    }

    return json;
  }

  SentryStackFrame copyWith({
    String? absPath,
    String? fileName,
    String? function,
    String? module,
    int? lineNo,
    int? colNo,
    String? contextLine,
    bool? inApp,
    String? package,
    bool? native,
    String? platform,
    String? imageAddr,
    String? symbolAddr,
    String? instructionAddr,
    String? rawFunction,
    List<int>? framesOmitted,
    List<String>? preContext,
    List<String>? postContext,
    Map<String, String>? vars,
  }) =>
      SentryStackFrame(
        absPath: absPath ?? this.absPath,
        fileName: fileName ?? this.fileName,
        function: function ?? this.function,
        module: module ?? this.module,
        lineNo: lineNo ?? this.lineNo,
        colNo: colNo ?? this.colNo,
        contextLine: contextLine ?? this.contextLine,
        inApp: inApp ?? this.inApp,
        package: package ?? this.package,
        native: native ?? this.native,
        platform: platform ?? this.platform,
        imageAddr: imageAddr ?? this.imageAddr,
        symbolAddr: symbolAddr ?? this.symbolAddr,
        instructionAddr: instructionAddr ?? this.instructionAddr,
        rawFunction: rawFunction ?? this.rawFunction,
        framesOmitted: framesOmitted ?? _framesOmitted,
        preContext: preContext ?? _preContext,
        postContext: postContext ?? _postContext,
        vars: vars ?? _vars,
      );
}
