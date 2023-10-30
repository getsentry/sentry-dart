import 'package:args/args.dart';
import 'package:file/local.dart';
import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';

const githubToken = String.fromEnvironment('GITHUB_TOKEN');
final githubAuth = githubToken.isEmpty
    ? Authentication.anonymous()
    : Authentication.withToken(githubToken);
final source = FlutterSymbolSource(githubAuth: githubAuth);
final fs = LocalFileSystem();
final tempDir = fs.currentDirectory.childDirectory('.temp');
final stateCache =
    DirectoryStatusCache(fs.currentDirectory.childDirectory('.cache'));
late final SymbolCollectorCli collector;

void main(List<String> arguments) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}'
        '${record.error == null ? '' : ': ${record.error}'}');
  });

  final parser = ArgParser()..addOption('version', defaultsTo: '');
  final args = parser.parse(arguments);
  final argVersion = args['version'] as String;

  collector = await SymbolCollectorCli.setup(tempDir);

  // If a specific version was given, run just for this version.
  if (argVersion.isNotEmpty &&
      !argVersion.contains('*') &&
      argVersion.split('.').length == 3) {
    Logger.root.info('Running for a single flutter version: $argVersion');
    await processFlutterVersion(FlutterVersion(argVersion));
  } else {
    // Otherwise, walk all the versions and run for the matching ones.
    final versionRegex = RegExp(argVersion.isEmpty
        ? '.*'
        : '^${argVersion.replaceAll('.', '\\.').replaceAll('*', '.+')}\$');
    Logger.root.info('Running for all Flutter versions matching $versionRegex');
    final versions = await source
        .listFlutterVersions()
        .where((v) => !v.isPreRelease)
        .where((v) => versionRegex.hasMatch(v.tagName))
        .toList();
    Logger.root.info(
        'Found ${versions.length} Flutter versions matching $versionRegex');
    for (var version in versions) {
      await processFlutterVersion(version);
    }
  }
}

Future<void> processFlutterVersion(FlutterVersion version) async {
  if (bool.hasEnvironment('CI')) {
    print('::group::Processing Flutter ${version.tagName}');
  }
  Logger.root.info('Processing Flutter ${version.tagName}');
  Logger.root.info('Engine version: ${await version.engineVersion}');

  final archives = await source.listSymbolArchives(version);
  final dir = tempDir.childDirectory(version.tagName);
  for (final archive in archives) {
    final status = await stateCache.getStatus(archive);
    if (status == SymbolArchiveStatus.success) {
      Logger.root
          .info('Skipping ${archive.path} - already processed successfully');
      continue;
    }

    final archiveDir = dir.childDirectory(archive.platform.operatingSystem);
    try {
      if (await source.downloadAndExtractTo(archiveDir, archive.path)) {
        if (await collector.upload(archiveDir, archive.platform, version)) {
          await stateCache.setStatus(archive, SymbolArchiveStatus.success);
          continue;
        }
      }
      await stateCache.setStatus(archive, SymbolArchiveStatus.error);
    } finally {
      if (await archiveDir.exists()) {
        await archiveDir.delete(recursive: true);
      }
    }
  }

  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }

  if (bool.hasEnvironment('CI')) {
    print('::endgroup::');
  }
}
