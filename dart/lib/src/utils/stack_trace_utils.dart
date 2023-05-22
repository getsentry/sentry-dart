import 'package:meta/meta.dart';

@internal
extension StackTraceUtils on String {
  bool isStackTrace() {
    final frameNumberPrefix = RegExp(r'^#\d+', multiLine: true);
    final matchesFrameNumber = frameNumberPrefix.hasMatch(this);

    final fileAndLineNumberSuffix =
        RegExp(r'.dart:\d+:\d+\)$', multiLine: true);
    final matchesFileAndLineNumber = fileAndLineNumberSuffix.hasMatch(this);

    final abs = RegExp(r'\s(abs)\s');
    final virt = RegExp(r'\s(virt)\s');
    final matchesAbsAndVirt = abs.hasMatch(this) & virt.hasMatch(this);

    final hexSuffix = RegExp(r'\+0(x)\w+$', multiLine: true);
    final matchesHexSuffix = hexSuffix.hasMatch(this);

    final isStackTrace = matchesFrameNumber & matchesFileAndLineNumber;
    final isObfuscatedStackTrace =
        matchesFrameNumber & (matchesAbsAndVirt || matchesHexSuffix);
    return isStackTrace || isObfuscatedStackTrace;
  }
}
