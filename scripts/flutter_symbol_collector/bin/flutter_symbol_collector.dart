import 'dart:io';

import 'package:file/local.dart';
import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:logging/logging.dart';

late final source = FlutterSymbolSource();
late final fs = LocalFileSystem();
late final tempDir = fs.currentDirectory.childDirectory('.temp');

void main(List<String> arguments) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}'
        '${record.error == null ? '' : ': ${record.error}'}');
  });

  // source
  //     .listFlutterVersions()
  //     .where((version) => !version.isPreRelease)
  //     .where((version) => version.tagName.startsWith('3.'))
  //     .forEach(processFlutterVerion);

  processFlutterVerion(FlutterVersion('3.13.7'));
}

Future<void> processFlutterVerion(FlutterVersion version) async {
  Logger.root.info('Processing Flutter ${version.tagName}');
  final engineVersion = await version.getEngineVersion();
  Logger.root.info('Engine version: $engineVersion');

  final archives = await source.listSymbolArchives(version);
  final dir = tempDir.childDirectory(version.tagName);
  for (final archive in archives) {
    final archiveDir = dir.childDirectory(archive.platform.operatingSystem);
    await source.downloadAndExtractTo(archiveDir, archive.path);
  }
}
