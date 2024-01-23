import 'package:gcloud/storage.dart';
import 'package:platform/platform.dart';

import 'symbol_archive.dart';

abstract class FlutterSymbolResolver {
  final String _prefix;
  final Bucket _bucket;
  final _resolvedFiles = List<SymbolArchive>.empty(growable: true);
  Platform get platform;

  FlutterSymbolResolver(this._bucket, String prefix)
      : _prefix = prefix.endsWith('/')
            ? prefix.substring(0, prefix.length - 1)
            : prefix;

  Future<void> tryResolve(String path) async {
    path = '$_prefix/$path';
    final matches = await _bucket
        .list(prefix: path)
        .where((v) => v.isObject)
        .where((v) => v.name == path) // because it's a prefix search
        .map((v) => v.name)
        .toList();
    if (matches.isNotEmpty) {
      _resolvedFiles.add(SymbolArchive(matches.single, platform));
    }
  }

  Future<List<SymbolArchive>> listArchives();
}

class IosSymbolResolver extends FlutterSymbolResolver {
  IosSymbolResolver(super.bucket, super.prefix);

  @override
  final platform = FakePlatform(operatingSystem: Platform.iOS);

  @override
  Future<List<SymbolArchive>> listArchives() async {
    await tryResolve('ios-release/Flutter.dSYM.zip');
    return _resolvedFiles;
  }
}

class MacOSSymbolResolver extends FlutterSymbolResolver {
  MacOSSymbolResolver(super.bucket, super.prefix);

  @override
  final platform = FakePlatform(operatingSystem: Platform.macOS);

  @override
  Future<List<SymbolArchive>> listArchives() async {
    // darwin-x64-release directory contains a fat (arm64+x86_64) binary.
    await tryResolve('darwin-x64-release/FlutterMacOS.dSYM.zip');
    return _resolvedFiles;
  }
}

class AndroidSymbolResolver extends FlutterSymbolResolver {
  final String architecture;

  AndroidSymbolResolver(super.bucket, super.prefix, this.architecture);

  @override
  final platform = FakePlatform(operatingSystem: Platform.android);

  @override
  Future<List<SymbolArchive>> listArchives() async {
    await tryResolve('android-$architecture-release/symbols.zip');
    return _resolvedFiles;
  }
}
