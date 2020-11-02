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
  String lineno;
  String colno;
  String absPath;
  String contextLine;
  bool inApp;
  String _package;
  bool _native;
  String platform;
  String imageAddr;
  String symbolAddr;
  String instructionAddr;
  String rawFunction;

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

    if (lineno != null) {
      json['lineno'] = lineno;
    }

    if (colno != null) {
      json['colno'] = colno;
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

    if (_package != null) {
      json['package'] = _package;
    }

    if (_native != null) {
      json['native'] = _native;
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
