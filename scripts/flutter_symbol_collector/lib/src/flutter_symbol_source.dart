import 'package:github/github.dart';
import 'package:gcloud/storage.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'flutter_version.dart';
import 'flutter_symbol_resolver.dart';
import 'symbol_archive.dart';

class FlutterSymbolSource {
  late final Logger _log;
  final _github = GitHub();
  late final _flutterRepo = RepositorySlug('flutter', 'flutter');
  late final _symbolsBucket =
      Storage(Client(), '').bucket('flutter_infra_release');

  FlutterSymbolSource({Logger? logger}) {
    _log = logger ?? Logger.root;
  }

  Stream<FlutterVersion> listFlutterVersions() => _github.repositories
      .listTags(_flutterRepo, perPage: 30)
      .map((t) => FlutterVersion(t.name));

  Future<List<SymbolArchive>> listSymbolArchives(FlutterVersion version) async {
    // example: https://console.cloud.google.com/storage/browser/flutter_infra_release/flutter/9064459a8b0dcd32877107f6002cc429a71659d1
    final prefix = 'flutter/${await version.getEngineVersion()}/';

    late final List<FlutterSymbolResolver> resolvers;
    if (version.tagName.startsWith('3.')) {
      resolvers = [
        IosSymbolResolver(_symbolsBucket, prefix),
        MacOSSymbolResolver(_symbolsBucket, prefix)
      ];
    } else {
      _log.warning('No symbol resolvers registered for ${version.tagName}');
      return [];
    }

    assert(resolvers.isNotEmpty);
    final archives = List<SymbolArchive>.empty(growable: true);
    for (var resolver in resolvers) {
      final files = await resolver.listArchives();
      if (files.isEmpty) {
        _log.warning(
            'Flutter ${version.tagName}: no debug symbols found by ${resolver.runtimeType}');
      } else {
        _log.fine(
            'Flutter ${version.tagName}: ${resolver.runtimeType} found debug symbols: ${files.map((v) => path.basename(v.path))}');
        archives.addAll(files);
      }
    }

    return archives;
  }

  Stream<List<int>> download(String path) => _symbolsBucket.read(path);
}
