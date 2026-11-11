import 'dart:io';

import 'package:meta/meta.dart';

/// Resolves the database path to pass to sentry-native.
///
/// Returns `null` to keep sentry-native's default, which is `.sentry-native`
/// in the current working directory.
///
/// On Windows, when no path is configured and that default can't be created
/// (packaged/MSIX apps, for example, start in `C:\Windows\System32`), this
/// falls back to `%LOCALAPPDATA%\<executable name>\sentry`. Without a writable
/// database, sentry-native fails to initialize and native crashes are lost.
@internal
String? resolveNativeDatabasePath({
  required String? configuredPath,
  required bool isWindows,
  required String workingDirectory,
  required Map<String, String> environment,
  required String resolvedExecutable,
}) {
  if (configuredPath != null || !isWindows) {
    return configuredPath;
  }
  if (_canCreateDefaultDatabase(workingDirectory)) {
    return null;
  }
  final localAppData = environment['LOCALAPPDATA'];
  if (localAppData == null) {
    return null;
  }
  final appName = resolvedExecutable
      .split(RegExp(r'[\\/]'))
      .last
      .replaceFirst(RegExp(r'\.exe$', caseSensitive: false), '');
  return '$localAppData\\$appName\\sentry';
}

/// Tries to create sentry-native's default database directory, which is the
/// most reliable way to know whether sentry-native will be able to use it.
bool _canCreateDefaultDatabase(String workingDirectory) {
  try {
    Directory(
      '$workingDirectory${Platform.pathSeparator}.sentry-native',
    ).createSync(recursive: true);
    return true;
  } on FileSystemException {
    return false;
  }
}
