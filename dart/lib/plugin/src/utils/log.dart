// Source partly borrowed from: https://github.com/YehudaKremer/msix/blob/main/lib/src/utils/log.dart

import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

int _numberOfAllTasks = 11;

class Log {
  static final _red = AnsiPen()..red(bold: true);
  static final _yellow = AnsiPen()..yellow(bold: true);
  static final _green = AnsiPen()..green(bold: true);
  static final _blue = AnsiPen()..blue(bold: true);
  static final _gray05 = AnsiPen()..gray(level: 0.5);
  static final _gray09 = AnsiPen()..gray(level: 0.9);
  static int _numberOfTasksCompleted = 0;
  static int _lastMessageLength = 0;

  /// Log with colors.
  Log();

  /// Information log with `white` color
  static void info(String message) => _write(message, withColor: _gray09);

  /// Error log with `red` color
  static void error(String message) => _write(message, withColor: _red);

  /// Warning log with `yellow` color
  static void warn(String message) => _write(message, withColor: _yellow);

  /// Success log with `green` color
  static void success(String message) => _write(message, withColor: _green);

  /// Link log with `blue` color
  static void link(String message) => _write(message, withColor: _blue);

  static void _write(String message, {required AnsiPen withColor}) {
    stdout.writeln();
    stdout.writeln(withColor(message));
  }

  static void _renderProgressBar() {
    stdout.writeCharCode(13);

    stdout.write(_gray09('['));
    var blueBars = '';
    for (var z = _numberOfTasksCompleted; z > 0; z--) {
      blueBars += '❚❚';
    }
    stdout.write(_blue(blueBars));
    var grayBars = '';
    for (var z = _numberOfAllTasks - _numberOfTasksCompleted; z > 0; z--) {
      grayBars += '❚❚';
    }
    stdout.write(_gray05(grayBars));

    stdout.write(_gray09(']'));
    stdout.write(_gray09(
        ' ${(_numberOfTasksCompleted * 100 / _numberOfAllTasks).floor()}%'));
  }

  /// Info log on a new task
  static void startingTask(String name) {
    final emptyStr = _getlastMessageemptyStringLength();
    _lastMessageLength = name.length;
    _renderProgressBar();
    stdout.write(_gray09(' $name..$emptyStr'));
  }

  /// Info log on a completed task
  static void taskCompleted(String name) {
    _numberOfTasksCompleted++;
    stdout.writeCharCode(13);
    stdout.write(_green('☑ '));
    stdout.writeln(
        '$name                                                             ');
    if (_numberOfTasksCompleted >= _numberOfAllTasks) {
      final emptyStr = _getlastMessageemptyStringLength();
      _renderProgressBar();
      stdout.writeln(emptyStr);
    }
  }

  static String _getlastMessageemptyStringLength() {
    var emptyStr = '';
    for (var i = 0; i < _lastMessageLength + 8; i++) {
      emptyStr += ' ';
    }
    return emptyStr;
  }

  /// Logs the ProcessResult depending if it's an error or success
  static void processResult(ProcessResult result) {
    // stderr and stdout can be a String if there were a value or
    // List<int> if null was used.
    String? stderr = (result.stderr != null && result.stderr is String)
        ? result.stderr
        : null;
    String? stdout = (result.stdout != null && result.stdout is String)
        ? result.stdout
        : null;

    final isError = result.exitCode != 0;

    if (isError) {
      Log.error(
          'exitCode: ${result.exitCode}\nstderr: $stderr\nstdout: $stdout');
      throw ExitError(result.exitCode);
    } else {
      Log.success('stderr: $stderr\nstdout: $stdout');
    }
  }
}

// Thrown instead of exit() for testability.
class ExitError {
  final int code;

  ExitError(this.code);
}
