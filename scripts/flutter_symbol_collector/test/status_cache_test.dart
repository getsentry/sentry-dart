import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:platform/platform.dart';
import 'package:test/test.dart';

import 'common.dart';

void main() {
  setupLogging();

  group('DirectoryStatusCache', () {
    late FileSystem fs;
    late SymbolArchiveStatusCache sut;
    final archive = SymbolArchive('path/to/archive.zip', LocalPlatform());

    setUp(() {
      fs = MemoryFileSystem.test();
      sut = DirectoryStatusCache(fs.currentDirectory);
    });

    test('retrieve unprocessed file', () async {
      expect(await sut.getStatus(archive), SymbolArchiveStatus.pending);
    });

    test('store and retrieve error', () async {
      await sut.setStatus(archive, SymbolArchiveStatus.error);
      expect(await sut.getStatus(archive), SymbolArchiveStatus.error);
    });

    test('store and retrieve success', () async {
      await sut.setStatus(archive, SymbolArchiveStatus.success);
      expect(await sut.getStatus(archive), SymbolArchiveStatus.success);
    });

    test('store, overwrite and retrieve', () async {
      await sut.setStatus(archive, SymbolArchiveStatus.error);
      expect(await sut.getStatus(archive), SymbolArchiveStatus.error);
      await sut.setStatus(archive, SymbolArchiveStatus.success);
      expect(await sut.getStatus(archive), SymbolArchiveStatus.success);
    });
  });
}
