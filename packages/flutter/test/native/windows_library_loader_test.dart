@TestOn('vm && (windows || linux || mac-os)')
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/native/c/windows_library_loader.dart';

void main() {
  late Directory temp;
  late String libraryPath;
  late String kernel32Path;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('sentry-loader-');
    final fixtures = Directory('test/native/fixtures/library_loader').absolute;
    for (final args in [
      ['-S', fixtures.path, '-B', temp.path],
      ['--build', temp.path, '--config', 'Release'],
    ]) {
      final result = await Process.run('cmake', args);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }
    final output = Platform.isWindows ? '${temp.path}/Release' : temp.path;
    final suffix = Platform.isMacOS ? 'dylib' : 'so';
    final original = Platform.isWindows
        ? '$output/slow_loader.dll'
        : '$output/libslow_loader.$suffix';
    libraryPath = '$output/טעינה איטית.${Platform.isWindows ? 'dll' : suffix}';
    await File(original).copy(libraryPath);
    kernel32Path = Platform.isWindows
        ? 'kernel32.dll'
        : '$output/libkernel32_fixture.$suffix';
  });

  tearDownAll(() async {
    if (!Platform.isWindows) await temp.delete(recursive: true);
  });

  test('slow library loading permits GC and survives helper exit', () async {
    final path = libraryPath;
    final kernel = kernel32Path;
    final watch = Stopwatch()..start();
    var previous = 0;
    var maxGap = 0;
    final retained = <Uint8List>[];
    final timer = Timer.periodic(Duration(milliseconds: 10), (_) {
      final now = watch.elapsedMilliseconds;
      final gap = now - previous;
      if (gap > maxGap) maxGap = gap;
      previous = now;
      for (var i = 0; i < 30; i++) {
        retained.add(Uint8List(256 * 1024));
        if (retained.length > 10) retained.removeAt(0);
      }
    });
    addTearDown(timer.cancel);
    await Isolate.run(() {
      WindowsLibraryLoader(DynamicLibrary.open(kernel)).load(path);
    });
    await Future<void>.delayed(Duration(milliseconds: 50));
    timer.cancel();
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(2900));
    expect(maxGap, lessThan(1500), reason: 'UI timer stopped during GC');

    final reopen = Stopwatch()..start();
    final library = DynamicLibrary.open(path);
    expect(
        library.lookupFunction<Int32 Function(), int Function()>(
            'fixture_value')(),
        42);
    expect(reopen.elapsedMilliseconds, lessThan(1500),
        reason: 'library constructor ran again after helper exit');
  });

  test('load failure crosses isolate with path and Win32 error code', () async {
    final path = '$libraryPath.missing';
    final kernel = kernel32Path;
    await expectLater(Isolate.run(() {
      WindowsLibraryLoader(DynamicLibrary.open(kernel)).load(path);
    }),
        throwsA(isA<OSError>()
            .having((error) => error.errorCode, 'Win32 error', 126)
            .having((error) => error.message, 'path', contains(path))));
  });
}
