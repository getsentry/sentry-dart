import 'package:file/file.dart';
import 'package:logging/logging.dart';

import 'symbol_archive.dart';

enum SymbolArchiveStatus {
  /// The archive has been successfully processed.
  success,

  /// The archive has been processed but there was an error.
  error,

  /// The archive hasn't been processed yet
  pending,
}

/// Stores and retrieves information about symbol processing status.
abstract class SymbolArchiveStatusCache {
  Future<void> setStatus(SymbolArchive archive, SymbolArchiveStatus status);
  Future<SymbolArchiveStatus> getStatus(SymbolArchive archive);
}

/// Stores information about symbol processing status in a local directory.
class DirectoryStatusCache implements SymbolArchiveStatusCache {
  final Directory _dir;

  DirectoryStatusCache(this._dir) {
    _dir.createSync(recursive: true);
  }

  File _statusFile(SymbolArchive archive) =>
      _dir.childFile('${archive.path.toLowerCase()}.status');

  @override
  Future<SymbolArchiveStatus> getStatus(SymbolArchive archive) async {
    final file = _statusFile(archive);
    if (!await file.exists()) {
      return SymbolArchiveStatus.pending;
    }
    return file.readAsString().then((value) {
      switch (value) {
        case 'success':
          return SymbolArchiveStatus.success;
        case 'error':
          return SymbolArchiveStatus.error;
        default:
          Logger.root.warning('Unknown status \'$value\' in $file');
          return SymbolArchiveStatus.error;
      }
    });
  }

  @override
  Future<void> setStatus(
      SymbolArchive archive, SymbolArchiveStatus status) async {
    final file = _statusFile(archive);
    Logger.root.info('Setting ${file.path} status to ${status.name}');
    await file.create(recursive: true);
    await file.writeAsString(status.name);
  }
}
