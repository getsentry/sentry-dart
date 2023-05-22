import 'package:meta/meta.dart';

@internal
class StackTraceUtils {
  StackTraceUtils(this.input);

  final String input;

  late final _stackStackTrace =
      RegExp(r'^#\d+.*\.dart:\d+:\d+\)$', multiLine: true);
  late final _flutterStackTrace =
      RegExp(r'^flutter:\s#\d+.*\.dart:\d+:\d+\)$', multiLine: true);
  late final _obfuscatedStackTrace =
      RegExp(r'^#\d+.*\+0x\w+$', multiLine: true);
  late final _multipleNewlines = RegExp(r'\n+');

  String removeStackStraceLines() {
    return input
        .replaceAll(_stackStackTrace, '')
        .replaceAll(_flutterStackTrace, '')
        .replaceAll(_obfuscatedStackTrace, '')
        .replaceAll('<asynchronous suspension>', '')
        .replaceAll(_multipleNewlines, '\n')
        .trim();
  }
}
