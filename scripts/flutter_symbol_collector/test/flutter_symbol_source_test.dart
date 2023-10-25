import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  setupLogging();
  late FileSystem fs;
  late FlutterSymbolSource sut;

  setUp(() {
    fs = MemoryFileSystem.test();
    sut = FlutterSymbolSource();
  });

  test('listFlutterVersions() returns a stable list', () async {
    final versions = await sut.listFlutterVersions().take(3).toList();
    expect(versions.map((v) => v.tagName),
        equals(['v1.16.3', 'v1.16.2', 'v1.16.1']));
  });

  test('listFlutterVersions() fetches items across multiple API page requests',
      () async {
    // the page size defaults to 30 at the moment, see listFlutterVersions()
    final versions = await sut.listFlutterVersions().take(105).toList();
    expect(versions.length, equals(105));
  });

  test('Engine versions match expected values', () async {
    final versions = await sut.listFlutterVersions().take(3).toList();
    final engines = List.empty(growable: true);
    for (var v in versions) {
      engines.add("${v.tagName} => ${await v.engineVersion}");
    }
    expect(
        engines,
        equals([
          'v1.16.3 => b2bdeb3f0f1683f3e0562f491b5e316240dfbc2c',
          'v1.16.2 => 2d42c74a348d98d2fd372a91953c104e58f185cd',
          'v1.16.1 => 216c420a2c06e5266a60a768b3fd0b660551cc9c'
        ]));
  });

  test('listSymbolArchives() supports expected platforms', () async {
    final archives = await sut.listSymbolArchives(FlutterVersion('3.13.4'));
    const prefix = 'flutter/9064459a8b0dcd32877107f6002cc429a71659d1';
    expect(
        archives.map((v) => '${v.platform.operatingSystem} - ${v.path}'),
        equals([
          'ios - $prefix/ios-release/Flutter.dSYM.zip',
          'macos - $prefix/darwin-x64-release/FlutterMacOS.dSYM.zip',
          'android - flutter/9064459a8b0dcd32877107f6002cc429a71659d1/android-arm-release/symbols.zip',
          'android - flutter/9064459a8b0dcd32877107f6002cc429a71659d1/android-arm64-release/symbols.zip'
        ]));
  });

  test('download() downloads the file', () async {
    // No need to download a large archive, just some small file to test this.
    final content = await sut
        .download('test.txt')
        .map(String.fromCharCodes)
        .reduce((a, b) => '$a$b');
    expect(content, equals('test\n'));
  });

  test('downloadAndExtractTo() downloads a plain file', () async {
    await sut.downloadAndExtractTo(fs.currentDirectory, 'test.txt');
    expect(fs.isFileSync('test.txt'), isTrue);
    expect(fs.file('test.txt').readAsStringSync(), equals('test\n'));
  });

  test('downloadAndExtractTo() extracts a zip file', () async {
    const path = 'flutter/0005149dca9b248663adcde4bdd7c6c915a76584';
    await sut.downloadAndExtractTo(fs.currentDirectory, '$path/sky_engine.zip');
    expect(fs.isDirectorySync('$path/sky_engine/sky_engine'), isTrue);
    expect(fs.file('$path/sky_engine/sky_engine/README.md').readAsStringSync(),
        startsWith('Flutter Engine'));
  });
}
