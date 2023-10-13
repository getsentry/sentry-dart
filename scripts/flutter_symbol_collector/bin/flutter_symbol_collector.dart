import 'package:args/args.dart';
import 'package:file/local.dart';
import 'package:flutter_symbol_collector/flutter_symbol_collector.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';

const githubToken = String.fromEnvironment('GITHUB_TOKEN');
final source = FlutterSymbolSource(
    githubAuth: githubToken.isEmpty
        ? Authentication.anonymous()
        : Authentication.withToken(githubToken));
final fs = LocalFileSystem();
final tempDir = fs.currentDirectory.childDirectory('.temp');
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
    await processFlutterVerion(FlutterVersion(argVersion));
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
      await processFlutterVerion(version);
    }
  }
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
    await collector.upload(archiveDir, archive.platform, version);
  }
}
