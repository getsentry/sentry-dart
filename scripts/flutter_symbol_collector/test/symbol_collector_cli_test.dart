import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:flutter_symbol_collector/src/flutter_version.dart';
import 'package:flutter_symbol_collector/src/symbol_collector_cli.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  setupLogging();

  group('setup() downloads CLI on', () {
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
    });
    for (final platform in [Platform.macOS, Platform.linux]) {
      test(platform, () async {
        const path = 'temp/symbol-collector';

        // make sure the file is overwritten if there's an older version
        await fs
            .file(path)
            .create(recursive: true)
            .then((file) => file.writeAsString('foo'));
        expect(fs.file(path).lengthSync(), equals(3));

        final originalPlatform = SymbolCollectorCli.platform;
        try {
          SymbolCollectorCli.platform = FakePlatform(operatingSystem: platform);
          final sut = await SymbolCollectorCli.setup(fs.directory('temp'));
          expect(sut.cli, equals(path));
          expect(fs.file(path).existsSync(), isTrue);
          expect(fs.file(path).lengthSync(), greaterThan(1000000));
        } finally {
          SymbolCollectorCli.platform = originalPlatform;
        }
      });
    }
  });

  group('execute', () {
    final tmpDir = LocalFileSystem()
        .systemTempDirectory
        .createTempSync('symbol_collector_test');
    late final SymbolCollectorCli sut;

    setUpAll(() async => sut = await SymbolCollectorCli.setup(tmpDir));
    tearDownAll(() => tmpDir.delete(recursive: true));

    test('getVersion()', () async {
      final output = await sut.getVersion();
      expect(output, startsWith('${SymbolCollectorCli.version}+'));
      expect(output.split("\n").length, equals(1));
    });

    test('upload()', () async {
      final uploadDir = LocalFileSystem()
          .systemTempDirectory
          .createTempSync('symbol_collector_upload_test');
      try {
        await sut.upload(
            uploadDir, LocalPlatform(), FlutterVersion('v0.0.0-test'));
      } finally {
        uploadDir.deleteSync();
      }
    });
  }, skip: LocalPlatform().isWindows);
}
