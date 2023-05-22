import 'package:meta/meta.dart';

@internal
class StackTraceUtils {
  static final _stackStackTrace =
      RegExp(r'^#\d+.*\.dart:\d+:\d+\)$', multiLine: true);
  static final _flutterStackTrace =
      RegExp(r'^flutter:\s#\d+.*\.dart:\d+:\d+\)$', multiLine: true);
  static final _obfuscatedStackTrace =
      RegExp(r'^#\d+.*\+0x\w+$', multiLine: true);
  static final _multipleNewlines = RegExp(r'\n+');

  static String removeStackStraceLines(String input) {
    return input
        .replaceAll(_stackStackTrace, '')
        .replaceAll(_flutterStackTrace, '')
        .replaceAll(_obfuscatedStackTrace, '')
        .replaceAll('<asynchronous suspension>', '')
        .replaceAll(_multipleNewlines, '\n')
        .trim();
  }
}
