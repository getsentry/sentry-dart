/// Equivalent to https://docs.oracle.com/javase/7/docs/api/java/lang/StackTraceElement.html
class JvmFrame {
  JvmFrame({
    this.className,
    this.fileName,
    this.method,
    this.lineNumber,
    this.skippedFrames,
    required this.isNativeMethod,
    required this.originalFrame,
  });

  factory JvmFrame.parse(String frame) {
    try {
      return _parse(frame);
    } catch (_) {
      return JvmFrame(
        isNativeMethod: false,
        originalFrame: frame,
      );
    }
  }

  static JvmFrame? tryParse(String frame) {
    try {
      return JvmFrame.parse(frame);
    } catch (_) {
      return null;
    }
  }

  /// Returns the fully qualified name of the class containing the execution
  /// point represented by this stack trace element.
  /// Example: `foo.bar.clazz`
  final String? className;

  /// Returns the name of the source file containing the execution point
  /// represented by this stack trace element.
  /// Example: `clazz.java`
  final String? fileName;

  /// Returns the name of the method containing the execution point represented
  /// by this stack trace element.
  final String? method;

  /// Returns the line number of the source line containing the execution point
  /// represented by this stack trace element.
  final int? lineNumber;

  /// Returns true if the method containing the execution point represented by
  /// this stack trace element is a native method.
  final bool isNativeMethod;

  /// Describes how many skipped frames this stack trace element contains
  /// For examples, this is 2, if the stack trace element contained of of the
  /// following texts:
  /// '... 2 more'
  /// '... 2 filtered'
  final int? skippedFrames;

  /// This is the unparsed original frames
  final String originalFrame;

  @override
  String toString() => originalFrame;

  bool get unparsed =>
      className == null &&
      fileName == null &&
      method == null &&
      lineNumber == null;

  // Examples:
  // at org.junit.Assert.fail(Assert.java:86)
  // Example with native method
  // sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
  static JvmFrame _parse(String jvmFrame) {
    var frame = jvmFrame.trim();
    if (frame.startsWith('...')) {
      // Examples:
      // '... 2 more'
      // '... 2 filtered'
      frame = frame.replaceAll('... ', '');
      frame = frame.replaceAll(' more', '');
      frame = frame.replaceAll(' filtered', '');
      return JvmFrame(
        isNativeMethod: false,
        originalFrame: jvmFrame,
        skippedFrames: int.tryParse(frame),
      );
    }
    if (!frame.startsWith('at')) {
      throw FormatException('frame seems to not be a jvm stacktrace', frame);
    }
    frame = frame.replaceFirst('at ', '');
    // now it is org.junit.Assert.fail(Assert.java:86)
    final splitted = frame.split('(');
    final packageAndMethod = splitted.first;
    final packageAndMethodSplitted = packageAndMethod.split('.');
    final fileAndLine = splitted[1].replaceAll(')', '');
    final fileAndLineSplitted = fileAndLine.split(':');

    final method = packageAndMethodSplitted.last;
    packageAndMethodSplitted.removeLast();

    final fileName = fileAndLineSplitted.first;
    final isNativeMethod = fileName == 'Native Method';
    var lineNumber =
        isNativeMethod ? null : int.tryParse(fileAndLineSplitted[1]);

    return JvmFrame(
      originalFrame: jvmFrame,
      fileName: isNativeMethod ? null : fileAndLineSplitted.first,
      lineNumber: lineNumber,
      method: method,
      className: packageAndMethodSplitted.join('.'),
      isNativeMethod: isNativeMethod,
    );
  }
}
