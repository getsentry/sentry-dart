import 'dart:io';

import '../../../sentry.dart';
import 'enricher_event_processor.dart';
import 'flutter_runtime.dart';
import 'io_platform_memory.dart';
import '../../utils/os_utils.dart';

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
  late final SentryOperatingSystem _os = getSentryOperatingSystem();
  bool _fetchedTotalPhysicalMemory = false;
  int? _totalPhysicalMemory;

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
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    event.contexts
      ..device = await _getDevice(event.contexts.device)
      ..operatingSystem = _getOperatingSystem(event.contexts.operatingSystem)
      ..runtimes = _getRuntimes(event.contexts.runtimes)
      ..app = _getApp(event.contexts.app)
      ..culture = _getSentryCulture(event.contexts.culture);

    event.contexts['dart_context'] = _getDartContext();
    return event;
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

  Future<SentryDevice> _getDevice(SentryDevice? device) async {
    device ??= SentryDevice();
    return device
      ..name = device.name ??
          (_options.sendDefaultPii ? Platform.localHostname : null)
      ..processorCount = device.processorCount ?? Platform.numberOfProcessors
      ..memorySize = device.memorySize
      ..memorySize = device.memorySize ?? await _getTotalPhysicalMemory()
      ..freeMemory = device.freeMemory;
  }

  Future<int?> _getTotalPhysicalMemory() async {
    if (!_fetchedTotalPhysicalMemory) {
      _totalPhysicalMemory =
          await PlatformMemory(_options).getTotalPhysicalMemory();
      _fetchedTotalPhysicalMemory = true;
    }
    return _totalPhysicalMemory;
  }

  SentryApp _getApp(SentryApp? app) {
    app ??= SentryApp();
    return app..appMemory = app.appMemory ?? ProcessInfo.currentRss;
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    if (os == null) {
      return SentryOperatingSystem(
        name: _os.name,
        version: _os.version,
        build: _os.build,
        kernelVersion: _os.kernelVersion,
        rooted: _os.rooted,
        rawDescription: _os.rawDescription,
        theme: _os.theme,
        unknown: _os.unknown,
      );
    } else {
      return _os.mergeWith(os);
    }
  }

  SentryCulture _getSentryCulture(SentryCulture? culture) {
    culture ??= SentryCulture();
    return culture
      ..locale = culture.locale ?? Platform.localeName
      ..timezone = culture.timezone ?? DateTime.now().timeZoneName;
  }
}
