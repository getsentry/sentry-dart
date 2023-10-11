import 'package:gcloud/storage.dart';

abstract class SymbolResolver {
  final String _prefix;
  final Bucket _bucket;
  final _resolvedFiles = List<String>.empty(growable: true);

  SymbolResolver(this._bucket, String prefix)
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
      _resolvedFiles.add(matches.single);
    }
  }

  Future<List<String>> listArchives();
}

class IosSymbolResolver extends SymbolResolver {
  IosSymbolResolver(super.bucket, super.prefix);

  @override
  Future<List<String>> listArchives() async {
    await tryResolve('ios-release/Flutter.dSYM.zip');
    return _resolvedFiles;
  }
}

class MacOSSymbolResolver extends SymbolResolver {
  MacOSSymbolResolver(super.bucket, super.prefix);

  @override
  Future<List<String>> listArchives() async {
    // darwin-x64-release directory contains a fat (arm64+x86_64) binary.
    await tryResolve('darwin-x64-release/FlutterMacOS.dSYM.zip');
    return _resolvedFiles;
  }
}
