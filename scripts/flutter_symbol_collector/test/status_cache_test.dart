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
    final version = FlutterVersion('1.2.3');
    final archive = SymbolArchive('path/to/archive.zip', LocalPlatform());

    setUp(() {
      fs = MemoryFileSystem.test();
      sut = DirectoryStatusCache(fs.currentDirectory);
    });

    test('retrieve unprocessed file', () async {
      expect(
          await sut.getStatus(version, archive), SymbolArchiveStatus.pending);
    });

    test('store and retrieve error', () async {
      await sut.setStatus(version, archive, SymbolArchiveStatus.error);
      expect(await sut.getStatus(version, archive), SymbolArchiveStatus.error);
    });

    test('store and retrieve success', () async {
      await sut.setStatus(version, archive, SymbolArchiveStatus.success);
      expect(
          await sut.getStatus(version, archive), SymbolArchiveStatus.success);
    });

    test('store, overwrite and retrieve', () async {
      await sut.setStatus(version, archive, SymbolArchiveStatus.error);
      expect(await sut.getStatus(version, archive), SymbolArchiveStatus.error);
      await sut.setStatus(version, archive, SymbolArchiveStatus.success);
      expect(
          await sut.getStatus(version, archive), SymbolArchiveStatus.success);
    });

    test('various flutter versions are independent', () async {
      await sut.setStatus(
          FlutterVersion('1.2.3'), archive, SymbolArchiveStatus.success);
      await sut.setStatus(
          FlutterVersion('5.6.7'), archive, SymbolArchiveStatus.error);
      expect(await sut.getStatus(FlutterVersion('1.2.3'), archive),
          SymbolArchiveStatus.success);
      expect(await sut.getStatus(FlutterVersion('5.6.7'), archive),
          SymbolArchiveStatus.error);
    });
  });
}
