// https://docs.oracle.com/javase/7/docs/api/java/lang/StackTraceElement.html
// https://docs.oracle.com/javase/7/docs/api/java/lang/Throwable.html#getStackTrace()
// ^\\tat ((?:(?:[\\d\\w]*\\.)*[\\d\\w]*))\\.([\\d\\w\\$]*)\\.([\\d\\w\\$]*)\\((?:(?:([\\d\\w]*\\.java):(\\d*))|([\\d\\w\\s]*))\\)$

final stackTraceRegEx = RegExp(
  r'^\\tat ((?:(?:[\\d\\w]*\\.)*[\\d\\w]*))\\.([\\d\\w\\$]*)\\.([\\d\\w\\$]*)\\((?:(?:([\\d\\w]*\\.java):(\\d*))|([\\d\\w\\s]*))\\)$',
);

class JvmFrame {
  JvmFrame({
    this.package,
    this.declaringClass,
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

  final String? package;
  final String? declaringClass;
  final String? fileName;
  final String? method;
  final int? lineNumber;
  final bool isNativeMethod;
  final int? skippedFrames;

  final String originalFrame;

  @override
  String toString() => originalFrame;

  bool get unparsed =>
      package == null &&
      declaringClass == null &&
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
    final className = packageAndMethodSplitted.last;
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
      declaringClass: className,
      isNativeMethod: isNativeMethod,
      package: packageAndMethodSplitted.join('.'),
    );
  }
}
