import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// Resolves the database path to pass to sentry-native.
///
/// Returns `null` to keep sentry-native's default, which is `.sentry-native`
/// in the current working directory.
///
/// On Windows, when no path is configured and that default isn't writable
/// (packaged/MSIX apps, for example, start in `C:\Windows\System32`), this
/// falls back to `%LOCALAPPDATA%\<executable name>\sentry-<DSN hash>`. Without
/// a writable database, sentry-native fails to initialize and native crashes
/// are lost.
///
/// On Linux, the same applies when the app starts in a read-only directory
/// (from a launcher with `/` as working directory, a Flatpak, Snap or
/// AppImage, a read-only install prefix, or a systemd service). It then
/// falls back to `$XDG_CACHE_HOME/<executable name>/sentry-<DSN hash>`, or
/// `$HOME/.cache/...` when `XDG_CACHE_HOME` is unset, empty or relative.
///
/// The DSN hash keeps apps that share an executable name from picking up each
/// other's pending reports, and it stays the same across app updates, unlike
/// the install path of a packaged app, which contains its version.
@internal
String? resolveNativeDatabasePath({
  required String? configuredPath,
  required bool isWindows,
  required bool isLinux,
  required String? dsn,
  required String Function() workingDirectory,
  required Map<String, String> environment,
  required String resolvedExecutable,
}) {
  if (configuredPath != null || !(isWindows || isLinux)) {
    return configuredPath;
  }
  if (_canWriteDefaultDatabase(workingDirectory)) {
    return null;
  }
  if (isLinux) {
    return _linuxFallbackPath(environment, resolvedExecutable, dsn);
  }
  final localAppData = environment['LOCALAPPDATA'];
  if (localAppData == null) {
    return null;
  }
  final appName = resolvedExecutable
      .split(RegExp(r'[\\/]'))
      .last
      .replaceFirst(RegExp(r'\.exe$', caseSensitive: false), '');
  return '$localAppData\\$appName\\sentry-${dsnHash(dsn ?? '')}';
}

/// `$XDG_CACHE_HOME/<executable name>/sentry-<DSN hash>`, or under
/// `$HOME/.cache` per the XDG Base Directory spec, which says to ignore an
/// empty or relative `XDG_CACHE_HOME`. Returns `null` if neither is usable.
String? _linuxFallbackPath(
  Map<String, String> environment,
  String resolvedExecutable,
  String? dsn,
) {
  var cacheHome = environment['XDG_CACHE_HOME'];
  if (cacheHome == null || !cacheHome.startsWith('/')) {
    final home = environment['HOME'];
    if (home == null || home.isEmpty) {
      return null;
    }
    cacheHome = '$home/.cache';
  }
  final appName = resolvedExecutable.split('/').last;
  return '$cacheHome/$appName/sentry-${dsnHash(dsn ?? '')}';
}

/// FNV-1a (32-bit) hash of [dsn] as 8 hex characters.
///
/// `String.hashCode` isn't guaranteed to be stable across runs or SDK
/// versions, and a changing hash would orphan pending crash reports.
@internal
String dsnHash(String dsn) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(dsn)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Checks that sentry-native will be able to write its default database by
/// creating `.sentry-native` and a file inside it. Creating the directory
/// alone succeeds when it already exists, even if it is read-only.
bool _canWriteDefaultDatabase(String Function() workingDirectory) {
  final File probe;
  try {
    final database = Directory(
      '${workingDirectory()}${Platform.pathSeparator}.sentry-native',
    )..createSync(recursive: true);
    probe = File('${database.path}${Platform.pathSeparator}.write-test-$pid')
      ..createSync();
  } on FileSystemException {
    // Also thrown when the working directory itself no longer exists.
    return false;
  }
  // Creating the file proved the directory is writable. Deleting it can fail
  // if another process, such as a virus scanner, still holds it open, and
  // sentry-native ignores a leftover file.
  try {
    probe.deleteSync();
  } on FileSystemException {
    // Best effort.
  }
  return true;
}
