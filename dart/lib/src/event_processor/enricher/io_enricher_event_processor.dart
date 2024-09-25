import 'dart:io';

import '../../../sentry.dart';
import 'enricher_event_processor.dart';
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

    // If there's a native integration available, it probably has better
    // information available than Flutter.

    final device = _options.platformChecker.hasNativeIntegration
        ? null
        : _getDevice(event.contexts.device);

    final os = _options.platformChecker.hasNativeIntegration
        ? null
        : _getOperatingSystem(event.contexts.operatingSystem);

    final culture = _options.platformChecker.hasNativeIntegration
        ? null
        : _getSentryCulture(event.contexts.culture);

    final contexts = event.contexts.copyWith(
      device: device,
      operatingSystem: os,
      runtimes: _getRuntimes(event.contexts.runtimes),
      app: app,
      culture: culture,
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
    if (runtimes == null) {
      return [dartRuntime];
    }
    return [
      ...runtimes,
      dartRuntime,
    ];
  }

  Map<String, dynamic> _getDartContext() {
    final args = Platform.executableArguments;
    final packageConfig = Platform.packageConfig;

    String? executable;
    if (_options.sendDefaultPii) {
      try {
        // This throws sometimes for some reason
        // https://github.com/flutter/flutter/issues/83921
        executable = Platform.executable;
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'Platform.executable couldn\'t be retrieved.',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }

    return <String, dynamic>{
      'compile_mode': _options.platformChecker.compileMode,
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
      name: device?.name ?? Platform.localHostname,
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
    return (os ?? SentryOperatingSystem()).copyWith(
      name: os?.name ?? Platform.operatingSystem,
      version: os?.version ?? Platform.operatingSystemVersion,
    );
  }

  SentryCulture _getSentryCulture(SentryCulture? culture) {
    return (culture ?? SentryCulture()).copyWith(
      locale: culture?.locale ?? Platform.localeName,
      timezone: culture?.timezone ?? DateTime.now().timeZoneName,
    );
  }
}
