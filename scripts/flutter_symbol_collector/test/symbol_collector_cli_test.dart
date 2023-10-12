import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:flutter_symbol_collector/src/symbol_collector_cli.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  setupLogging();
  late FileSystem fs;

  setUp(() {
    fs = MemoryFileSystem.test();
  });

  group('setup() downloads CLI on', () {
    for (final platform in [Platform.macOS, Platform.linux]) {
      test(platform, () async {
        const path = 'temp/symbol-collector';

        // make sure the file is overwritten if there's an older version
        await fs
            .file(path)
            .create(recursive: true)
            .then((file) => file.writeAsString('foo'));
        expect(fs.file(path).lengthSync(), equals(3));

        SymbolCollectorCli.platform = FakePlatform(operatingSystem: platform);
        final sut = await SymbolCollectorCli.setup(fs.directory('temp'));
        expect(sut.cli, equals(path));
        expect(fs.file(path).existsSync(), isTrue);
        expect(fs.file(path).lengthSync(), greaterThan(1000000));
      });
    }
  });

  group('execute', () {
    final tmpDir = LocalFileSystem()
        .systemTempDirectory
        .createTempSync('symbol_collector_test');
    late final SymbolCollectorCli sut;

    setUp(() async => sut = await SymbolCollectorCli.setup(tmpDir));
    tearDown(() => tmpDir.delete(recursive: true));

    test('getVersion()', () async {
      final versionString = await sut.getVersion();
      expect(versionString, startsWith('${SymbolCollectorCli.version}+'));
      expect(versionString.split("\n").length, equals(1));
    });
  }, skip: LocalPlatform().isWindows);
}
