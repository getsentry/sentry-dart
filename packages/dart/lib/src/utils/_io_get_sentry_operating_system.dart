import '../protocol/sentry_operating_system.dart';
import 'dart:convert';
import 'dart:io';
import 'package:meta/meta.dart';

@internal
SentryOperatingSystem getSentryOperatingSystem({
  String? name,
  String? rawDescription,
}) {
  // #region agent log
  _debugLog({
    'location': '_io_get_sentry_operating_system.dart:11',
    'message': 'getSentryOperatingSystem entry',
    'data': {
      'inputName': name,
      'inputRawDescription': rawDescription,
      'platformName': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
    },
    'hypothesisId': 'H1',
  });
  // #endregion
  name ??= Platform.operatingSystem;
  rawDescription ??= Platform.operatingSystemVersion;
  RegExpMatch? match;
  switch (name) {
    case 'android':
      match = _androidOsRegexp.firstMatch(rawDescription);
      name = 'Android';
      break;
    case 'ios':
      name = 'iOS';
      match = _appleOsRegexp.firstMatch(rawDescription);
      break;
    case 'macos':
      name = 'macOS';
      match = _appleOsRegexp.firstMatch(rawDescription);
      break;
    case 'linux':
      name = 'Linux';
      match = _linuxOsRegexp.firstMatch(rawDescription);
      break;
    case 'windows':
      name = 'Windows';
      match = _windowsOsRegexp.firstMatch(rawDescription);
      break;
  }
  // #region agent log
  _debugLog({
    'location': '_io_get_sentry_operating_system.dart:44',
    'message': 'parsed operating system',
    'data': {
      'normalizedName': name,
      'rawDescription': rawDescription,
      'matchFound': match != null,
      'matchValue': match?.group(0),
      'version': match?.namedGroupOrNull('version'),
      'build': match?.namedGroupOrNull('build'),
      'kernelVersion': match?.namedGroupOrNull('kernelVersion'),
    },
    'hypothesisId': 'H1',
  });
  // #endregion
  final version = match?.namedGroupOrNull('version');
  final build = match?.namedGroupOrNull('build');
  final kernelVersion = match?.namedGroupOrNull('kernelVersion');
  // #region agent log
  _debugLog({
    'location': '_io_get_sentry_operating_system.dart:61',
    'message': 'operating system result',
    'data': {
      'name': name,
      'rawDescription': rawDescription,
      'version': version,
      'build': build,
      'kernelVersion': kernelVersion,
    },
    'hypothesisId': 'H4',
  });
  // #endregion

  return SentryOperatingSystem(
    name: name,
    rawDescription: rawDescription,
    version: version,
    build: build,
    kernelVersion: kernelVersion,
  );
}

// LYA-L29 10.1.0.289(C432E7R1P5)
// TE1A.220922.010
final _androidOsRegexp = RegExp('^(?<build>.*)\$', caseSensitive: false);

// Linux 5.11.0-1018-gcp #20~20.04.2-Ubuntu SMP Fri Sep 3 01:01:37 UTC 2021
final _linuxOsRegexp = RegExp(
    '(?<kernelVersion>[a-z0-9+.\\-]+) (?<build>#.*)\$',
    caseSensitive: false);

// Version 14.5 (Build 18E182)
final _appleOsRegexp = RegExp(
    '(?<version>[a-z0-9+.\\-]+)( \\(Build (?<build>[a-z0-9+.\\-]+))\\)?\$',
    caseSensitive: false);

// "Windows 10 Pro" 10.0 (Build 19043)
final _windowsOsRegexp = RegExp(
    ' (?<version>[a-z0-9+.\\-]+)( \\(Build (?<build>[a-z0-9+.\\-]+))\\)?\$',
    caseSensitive: false);

extension on RegExpMatch {
  String? namedGroupOrNull(String name) {
    if (groupNames.contains(name)) {
      return namedGroup(name);
    } else {
      return null;
    }
  }
}

void _debugLog(Map<String, Object?> payload) {
  try {
    final entry = <String, Object?>{
      'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
      'runId': 'pre-fix',
      'hypothesisId': payload['hypothesisId'],
      'location': payload['location'],
      'message': payload['message'],
      'data': payload['data'],
    };
    File('/Users/giancarlobuenaflor/Desktop/sentry-projects/dart-new6/.cursor/debug.log')
        .writeAsStringSync('${jsonEncode(entry)}\n',
            mode: FileMode.append, flush: true);
  } catch (_) {}
}
