import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  Logger.root.level = Level.ALL;
  late FlutterSymbolDownloader sut;

  setUp(() {
    sut = FlutterSymbolDownloader();
  });

  test('$FlutterVersion.isPrerelease()', () async {
    expect(FlutterVersion('v1.16.3').isPreRelease, false);
    expect(FlutterVersion('v1.16.3.pre').isPreRelease, true);
    expect(FlutterVersion('3.16.0-9.0').isPreRelease, false);
    expect(FlutterVersion('3.16.0-9.0.pre').isPreRelease, true);
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
      engines.add("${v.tagName} => ${await v.getEngineVersion()}");
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
        archives,
        equals([
          '$prefix/ios-release/Flutter.dSYM.zip',
          '$prefix/darwin-x64-release/FlutterMacOS.dSYM.zip'
        ]));
  });

  test('listSymbolArchives() supports expected platforms', () async {
    final archives = await sut.listSymbolArchives(FlutterVersion('3.13.4'));
    const prefix = 'flutter/9064459a8b0dcd32877107f6002cc429a71659d1';
    expect(
        archives,
        equals([
          '$prefix/ios-release/Flutter.dSYM.zip',
          '$prefix/darwin-x64-release/FlutterMacOS.dSYM.zip'
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
}
