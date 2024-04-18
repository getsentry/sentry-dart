@TestOn('vm')
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// Tests for the following issue
// https://github.com/getsentry/sentry-dart/issues/1893
void main() {
  group('Compile example_web', () {
    test(
      'dart pub get and compilation should run successfully',
      () async {
        final result = await _runProcess('dart pub get',
            workingDirectory: _exampleWebWorkingDir);
        expect(result.exitCode, 0,
            reason: 'Could run `dart pub get` for example_web. '
                'Likely caused by outdated dependencies');
        // running this test locally require clean working directory
        final cleanResult = await _runProcess('dart run build_runner clean',
            workingDirectory: _exampleWebWorkingDir);
        expect(cleanResult.exitCode, 0);
        final compileResult = await _runProcess(
            'dart run build_runner build -r web -o build --delete-conflicting-outputs',
            workingDirectory: _exampleWebWorkingDir);
        expect(compileResult.exitCode, 0,
            reason: 'Could not compile example_web project');
        expect(
            compileResult.stdout,
            isNot(contains(
                'Skipping compiling sentry_dart_web_example|web/main.dart')),
            reason:
                'Could not compile main.dart, likely because of dart:io import.');
        expect(
            compileResult.stdout,
            contains(
                'build_web_compilers:entrypoint on web/main.dart:Compiled'));
      },
      timeout: Timeout(const Duration(minutes: 1)), // double of detault timeout
    );
  });
}

/// Runs [command] with command's stdout and stderr being forwrarded to
/// test runner's respective streams. It buffers stdout and returns it.
///
/// Returns [_CommandResult] with exitCode and stdout as a single sting
Future<_CommandResult> _runProcess(String command,
    {String workingDirectory = '.'}) async {
  final parts = command.split(' ');
  assert(parts.isNotEmpty);
  final cmd = parts[0];
  final args = parts.skip(1).toList();
  final process =
      await Process.start(cmd, args, workingDirectory: workingDirectory);
  // forward standard streams
  unawaited(stderr.addStream(process.stderr));
  final buffer = <int>[];
  final stdoutCompleter = Completer.sync();
  process.stdout.listen(
    (units) {
      buffer.addAll(units);
      stdout.add(units);
    },
    cancelOnError: true,
    onDone: () {
      stdoutCompleter.complete();
    },
  );
  await stdoutCompleter.future;
  final processOut = utf8.decode(buffer);
  int exitCode = await process.exitCode;
  return _CommandResult(exitCode: exitCode, stdout: processOut);
}

String get _exampleWebWorkingDir {
  return '${Directory.current.path}${Platform.pathSeparator}example_web';
}

class _CommandResult {
  final int exitCode;
  final String stdout;

  const _CommandResult({required this.exitCode, required this.stdout});
}
