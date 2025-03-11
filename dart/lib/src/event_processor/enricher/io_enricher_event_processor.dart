import 'dart:io';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import 'enricher_event_processor.dart';
import 'flutter_runtime.dart';
import 'io_platform_memory.dart';

EnricherEventProcessor enricherEventProcessor(SentryOptions options) {
  return IoEnricherEventProcessor(options);
}

/// Enriches [SentryEvent]s with various kinds of information.
/// Uses Darts [Platform](https://api.dart.dev/stable/dart-io/Platform-class.html)
/// class to read information.
class IoEnricherEventProcessor implements EnricherEventProcessor {
  IoEnricherEventProcessor(this._options);

  final SentryOptions _options;
  late final String _dartVersion = _extractDartVersion(Platform.version);
  late final SentryOperatingSystem _os = extractOperatingSystem(
      Platform.operatingSystem, Platform.operatingSystemVersion);

  /// Extracts the semantic version and channel from the full version string.
  ///
  /// Example:
  /// Input: "3.5.0-180.3.beta (beta) (Wed Jun 5 15:06:15 2024 +0000) on "android_arm64""
  /// Output: "3.5.0-180.3.beta (beta)"
  ///
  /// Falls back to the full version if the matching fails.
  String _extractDartVersion(String fullVersion) {
    RegExp channelRegex = RegExp(r'\((stable|beta|dev)\)');
    Match? match = channelRegex.firstMatch(fullVersion);
    // if match is null this will return the full version
    return fullVersion.substring(0, match?.end);
  }

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    // Amend app with current memory usage, as this is not available on native.
    final app = _getApp(event.contexts.app);

    final contexts = event.contexts.copyWith(
      device: _getDevice(event.contexts.device),
      operatingSystem: _getOperatingSystem(event.contexts.operatingSystem),
      runtimes: _getRuntimes(event.contexts.runtimes),
      app: app,
      culture: _getSentryCulture(event.contexts.culture),
    );

    contexts['dart_context'] = _getDartContext();

    return event.copyWith(
      contexts: contexts,
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    // Pure Dart doesn't have specific runtimes per build mode
    // like Flutter: https://flutter.dev/docs/testing/build-modes
    final dartRuntime = SentryRuntime(
      name: 'Dart',
      version: _dartVersion,
      rawDescription: Platform.version,
    );
    final flRuntime = flutterRuntime;

    if (runtimes == null) {
      return [dartRuntime, if (flRuntime != null) flRuntime];
    }
    return [
      ...runtimes,
      dartRuntime,
      if (flRuntime != null) flRuntime,
    ];
  }

  Map<String, dynamic> _getDartContext() {
    final args = Platform.executableArguments;
    final packageConfig = Platform.packageConfig;

    String? executable;
    if (_options.sendDefaultPii) {
      executable = Platform.executable;
    }

    return <String, dynamic>{
      'compile_mode': _options.runtimeChecker.compileMode,
      if (packageConfig != null) 'package_config': packageConfig,
      // The following information could potentially contain PII
      if (_options.sendDefaultPii) ...{
        'executable': executable,
        'resolved_executable': Platform.resolvedExecutable,
        'script': Platform.script.toString(),
        if (args.isNotEmpty)
          'executable_arguments': Platform.executableArguments,
      },
    };
  }

  SentryDevice _getDevice(SentryDevice? device) {
    final platformMemory = PlatformMemory(_options);
    return (device ?? SentryDevice()).copyWith(
      name: device?.name ??
          (_options.sendDefaultPii ? Platform.localHostname : null),
      processorCount: device?.processorCount ?? Platform.numberOfProcessors,
      memorySize: device?.memorySize ?? platformMemory.getTotalPhysicalMemory(),
      freeMemory: device?.freeMemory ?? platformMemory.getFreePhysicalMemory(),
    );
  }

  SentryApp _getApp(SentryApp? app) {
    return (app ?? SentryApp()).copyWith(
      appMemory: app?.appMemory ?? ProcessInfo.currentRss,
    );
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    if (os == null) {
      return _os.clone();
    } else {
      return _os.mergeWith(os);
    }
  }

  @internal
  SentryOperatingSystem extractOperatingSystem(
      String name, String rawDescription) {
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

    return SentryOperatingSystem(
      name: name,
      rawDescription: rawDescription,
      version: match?.namedGroupOrNull('version'),
      build: match?.namedGroupOrNull('build'),
      kernelVersion: match?.namedGroupOrNull('kernelVersion'),
    );
  }

  SentryCulture _getSentryCulture(SentryCulture? culture) {
    return (culture ?? SentryCulture()).copyWith(
      locale: culture?.locale ?? Platform.localeName,
      timezone: culture?.timezone ?? DateTime.now().timeZoneName,
    );
  }
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
