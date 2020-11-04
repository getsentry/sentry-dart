class SentryStackFrame {
  static final SentryStackFrame asynchronousGapFrameJson =
      SentryStackFrame(absPath: '<asynchronous suspension>');

  SentryStackFrame({
    this.absPath,
    this.preContext,
    this.postContext,
    this.vars,
    this.filename,
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
    this.origin = '',
    List<int> framesOmitted,
    List<String> preContrxt,
  }) : _framesOmitted = framesOmitted;

  /// The absolute path to filename.
  final String absPath;

  /// A list of source code lines before context_line (in order) – usually [lineno - 5:lineno].
  final List<String> preContext;

  /// A list of source code lines after context_line (in order) – usually [lineno + 1:lineno + 5].
  final List<String> postContext;

  /// A mapping of variables which were available within this frame (usually context-locals).
  final Map<String, String> vars;

  /// Which frames were omitted, if any.
  ///
  /// If the list of frames is large, you can explicitly tell the system
  /// that you’ve omitted a range of frames.
  /// The frames_omitted must be a single tuple two values: start and end.
  //
  /// Example : If you only removed the 8th frame, the value would be (8, 9),
  /// meaning it started at the 8th frame, and went untilthe 9th (the number of frames omitted is end-start).
  /// The values should be based on a one-index.
  final List<int> _framesOmitted;

  List<int> get framesOmitted => List.unmodifiable(_framesOmitted);

  /// The relative file path to the call.
  final String filename;

  /// The name of the function being called.
  final String function;

  /// Platform-specific module path.
  final String module;

  /// The column number of the call
  final int lineNo;

  /// The column number of the call
  final int colNo;

  /// Source code in filename at line number.
  final String contextLine;

  /// Signifies whether this frame is related to the execution of the relevant code in this stacktrace.
  ///
  /// For example, the frames that might power the framework’s web server of your app are probably not relevant, however calls to the framework’s library once you start handling code likely are.
  final bool inApp;

  /// The "package" the frame was contained in.
  final String package;

  final bool native;

  /// This can override the platform for a single frame. Otherwise, the platform of the event is assumed. This can be used for multi-platform stack traces
  final String platform;

  /// Optionally an address of the debug image to reference.
  final String imageAddr;

  /// An optional address that points to a symbol. We use the instruction address for symbolication, but this can be used to calculate an instruction offset automatically.
  final String symbolAddr;

  /// The instruction address
  /// The official docs refer to it as 'The difference between instruction address and symbol address in bytes.'
  final String instructionAddr;

  /// The original function name, if the function name is shortened or demangled. Sentry shows the raw function when clicking on the shortened one in the UI.
  final String rawFunction;

  ///
  final String origin;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (preContext?.isNotEmpty ?? false) {
      json['pre_context'] = preContext;
    }

    if (postContext?.isNotEmpty ?? false) {
      json['post_context'] = postContext;
    }

    if (vars?.isNotEmpty ?? false) {
      json['vars'] = vars;
    }

    if (framesOmitted?.isNotEmpty ?? false) {
      json['frames_omitted'] = framesOmitted;
    }

    if (filename != null) {
      json['filename'] = filename;
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
      json['abs_path'] = '$origin$absPath';
    }

    if (contextLine != null) {
      json['context_line'] = contextLine;
    }

    if (inApp != null) {
      json['in_app'] = inApp;
    }

    if (package != null) {
      json['package'] = package;
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
}
