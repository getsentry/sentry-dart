import 'package:file/file.dart';
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

  test('exec() works', () async {
    final sut = await SymbolCollectorCli.setup(fs.currentDirectory);
    expect(sut.getVersion(), startsWith('${SymbolCollectorCli.version}+'));
  }, skip: LocalPlatform().isWindows);
}
