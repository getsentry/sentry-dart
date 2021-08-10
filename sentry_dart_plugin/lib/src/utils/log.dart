import 'dart:io';
import 'package:ansicolor/ansicolor.dart';

int numberOfAllTasks = 11;

class Log {
  static AnsiPen red = AnsiPen()..red(bold: true);
  static AnsiPen yellow = AnsiPen()..yellow(bold: true);
  static AnsiPen green = AnsiPen()..green(bold: true);
  static AnsiPen blue = AnsiPen()..blue(bold: true);
  static AnsiPen gray05 = AnsiPen()..gray(level: 0.5);
  static AnsiPen gray09 = AnsiPen()..gray(level: 0.9);
  static int _numberOfTasksCompleted = 0;
  static int lastMessageLength = 0;

  /// Log with colors.
  Log();

  /// Information log with `white` color
  static void info(String message) => _write(message, withColor: gray09);

  /// Error log with `red` color
  static void error(String message) {
    stdout.writeln();
    _write(message, withColor: red);
  }

  /// Write `error` log and exit the program
  static void errorAndExit(String message) {
    error(message);
    exit(0);
  }

  /// Warning log with `yellow` color
  static void warn(String message) => _write(message, withColor: yellow);

  /// Success log with `green` color
  static void success(String message) => _write(message, withColor: green);

  /// Link log with `blue` color
  static void link(String message) => _write(message, withColor: blue);

  static void _write(String message, {required AnsiPen withColor}) {
    stdout.writeln(withColor(message));
  }

  static void _renderProgressBar() {
    stdout.writeCharCode(13);

    stdout.write(gray09('['));
    var blueBars = '';
    for (var z = _numberOfTasksCompleted; z > 0; z--) {
      blueBars += '❚❚';
    }
    stdout.write(blue(blueBars));
    var grayBars = '';
    for (var z = numberOfAllTasks - _numberOfTasksCompleted; z > 0; z--) {
      grayBars += '❚❚';
    }
    stdout.write(gray05(grayBars));

    stdout.write(gray09(']'));
    stdout.write(gray09(
        ' ${(_numberOfTasksCompleted * 100 / numberOfAllTasks).floor()}%'));
  }

  /// Info log on a new task
  static void startingTask(String name) {
    final emptyStr = _getlastMessageemptyStringLength();
    lastMessageLength = name.length;
    _renderProgressBar();
    stdout.write(gray09(' $name..$emptyStr'));
  }

  /// Info log on a completed task
  static void taskCompleted(String name) {
    _numberOfTasksCompleted++;
    stdout.writeCharCode(13);
    stdout.write(green('☑ '));
    stdout.writeln(
        '$name                                                             ');
    if (_numberOfTasksCompleted >= numberOfAllTasks) {
      final emptyStr = _getlastMessageemptyStringLength();
      _renderProgressBar();
      stdout.writeln(emptyStr);
    }
  }

  static String _getlastMessageemptyStringLength() {
    var emptyStr = '';
    for (var i = 0; i < lastMessageLength + 8; i++) {
      emptyStr += ' ';
    }
    return emptyStr;
  }

  static void processResult(ProcessResult result) {
    if (result.stderr.toString().length > 0) {
      Log.error(result.stdout);
      Log.errorAndExit(result.stderr);
    } else if (result.exitCode != 0) {
      Log.errorAndExit(result.stdout);
    } else {
      Log.success(result.stdout);
    }
  }
}
