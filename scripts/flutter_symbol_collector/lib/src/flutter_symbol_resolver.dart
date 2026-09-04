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

  Future<bool> tryResolve(String path) async {
    path = '$_prefix/$path';
    final matches = await _bucket
        .list(prefix: path)
        .where((v) => v.isObject)
        .where((v) => v.name == path) // because it's a prefix search
        .map((v) => v.name)
        .toList();
    if (matches.isEmpty) {
      return false;
    }

    _resolvedFiles.add(SymbolArchive(matches.single, platform));
    return true;
  }

  Future<List<SymbolArchive>> listArchives();
}

class IosSymbolResolver extends FlutterSymbolResolver {
  IosSymbolResolver(super.bucket, super.prefix);

  @override
  final platform = FakePlatform(operatingSystem: Platform.iOS);

  @override
  Future<List<SymbolArchive>> listArchives() async {
    // Since Flutter 3.24, dSYMs are embedded in the artifact cache's
    // Flutter.xcframework instead of always being uploaded separately.
    // See https://github.com/flutter/flutter/blob/main/docs/engine/Crashes.md#ios.
    if (!await tryResolve('ios-release/Flutter.dSYM.zip')) {
      await tryResolve('ios-release/artifacts.zip');
    }
    return _resolvedFiles;
  }
}

class MacOSSymbolResolver extends FlutterSymbolResolver {
  MacOSSymbolResolver(super.bucket, super.prefix);

  @override
  final platform = FakePlatform(operatingSystem: Platform.macOS);

  @override
  Future<List<SymbolArchive>> listArchives() async {
    // Since Flutter 3.27, dSYMs are embedded in the artifact cache's
    // FlutterMacOS.xcframework instead of being uploaded separately.
    // See https://github.com/flutter/flutter/blob/main/docs/engine/Crashes.md#macos.
    if (!await tryResolve('darwin-x64-release/FlutterMacOS.dSYM.zip')) {
      await tryResolve('darwin-x64-release/framework.zip');
    }
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
