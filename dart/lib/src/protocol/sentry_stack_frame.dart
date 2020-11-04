class SentryStackFrame {
  static final SentryStackFrame asynchronousGapFrameJson = SentryStackFrame()
    ..absPath = '<asynchronous suspension>';

  List<String> preContext;
  List<String> postContext;
  Map<String, String> vars;
  List<int> framesOmitted;
  String filename;
  String function;
  String module;
  int lineNo;
  int colNo;
  String absPath;
  String contextLine;
  bool inApp;
  String package;
  bool native;
  String platform;
  String imageAddr;
  String symbolAddr;
  String instructionAddr;
  String rawFunction;

  Map<String, dynamic> toJson([String origin = '']) {
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
