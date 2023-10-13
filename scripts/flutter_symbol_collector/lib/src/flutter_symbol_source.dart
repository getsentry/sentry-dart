import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file/file.dart';
import 'package:github/github.dart' as github;
import 'package:gcloud/storage.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'flutter_version.dart';
import 'flutter_symbol_resolver.dart';
import 'symbol_archive.dart';

class FlutterSymbolSource {
  late final Logger _log;
  final github.GitHub _github;
  late final _flutterRepo = github.RepositorySlug('flutter', 'flutter');
  late final _symbolsBucket =
      Storage(Client(), '').bucket('flutter_infra_release');

  FlutterSymbolSource(
      {Logger? logger,
      github.Authentication githubAuth =
          const github.Authentication.anonymous()})
      : _log = logger ?? Logger.root,
        _github = github.GitHub(auth: githubAuth);

  Stream<FlutterVersion> listFlutterVersions() => _github.repositories
      .listTags(_flutterRepo, perPage: 30)
      .map((t) => FlutterVersion(t.name));

  Future<List<SymbolArchive>> listSymbolArchives(FlutterVersion version) async {
    // example: https://console.cloud.google.com/storage/browser/flutter_infra_release/flutter/9064459a8b0dcd32877107f6002cc429a71659d1
    final prefix = 'flutter/${await version.engineVersion}/';

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
            'Flutter ${version.tagName}: ${resolver.runtimeType} found ${files.length} debug symbols: ${files.map((v) => path.basename(v.path))}');
        archives.addAll(files);
      }
    }

    return archives;
  }

  // Streams the remote file contents.
  Stream<List<int>> download(String filePath) {
    _log.fine('Downloading $filePath');
    return _symbolsBucket.read(filePath);
  }

  // Downloads the remote file to the given target directory or if it's an
  //archive, extracts the content instead.
  Future<void> downloadAndExtractTo(Directory target, String filePath) async {
    if (path.extension(filePath) == '.zip') {
      target = await target
          .childDirectory(path.withoutExtension(filePath))
          .create(recursive: true);
      try {
        final buffer = BytesBuilder();
        await download(filePath).forEach(buffer.add);
        final archive = ZipDecoder().decodeBytes(buffer.toBytes());
        buffer.clear();
        _log.fine('Extracting $filePath to $target');
        await _extractZip(target, archive);
      } catch (e, trace) {
        _log.warning('Failed to download $filePath to $target', e, trace);
        // Remove the directory so that we don't leave a partial extraction.
        await target.delete(recursive: true);
      }
    } else {
      _log.fine('Downloading $filePath to $target');
      final file = await target
          .childFile(filePath)
          .create(recursive: true, exclusive: true);
      final sink = file.openWrite();
      try {
        await sink.addStream(download(filePath));
        await sink.flush();
        await sink.close();
      } catch (e, trace) {
        _log.warning('Failed to download $filePath to $target', e, trace);
        await sink.close();
        await file.delete();
      }
    }
  }

  Future<void> _extractZip(Directory target, Archive archive) async {
    for (var entry in archive.files) {
      // Make sure we don't have any zip-slip issues.
      final entryPath = path.normalize(entry.name);
      if (!path
          .normalize(target.childFile(entryPath).path)
          .startsWith(target.path)) {
        throw Exception(
            'Invalid ZIP entry path (looks like a zip-slip issue): ${entry.name}');
      }

      if (!entry.isFile) {
        // If it's a directory - create it.
        await target.childDirectory(entryPath).create(recursive: true);
      } else {
        // Note: package:archive doesn't support extracting directly to an
        // IOSink. See https://github.com/brendan-duncan/archive/issues/12
        final stream = OutputStream();
        entry.writeContent(stream, freeMemory: true);
        stream.flush();

        // If it's an inner ZIP archive - extract it recursively.
        if (path.extension(entryPath) == '.zip') {
          final innerArchive = ZipDecoder().decodeBytes(stream.getBytes());
          stream.clear();
          final innerTarget = target
              .childDirectory(path.withoutExtension(path.normalize(entryPath)));
          _log.fine('Extracting inner archive $entryPath to $innerTarget');
          await _extractZip(innerTarget, innerArchive);
        } else {
          final file = await target
              .childFile(path.normalize(entryPath))
              .create(exclusive: true);
          await file.writeAsBytes(stream.getBytes(), flush: true);
        }
      }
    }
  }
}
