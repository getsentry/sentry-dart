import 'dart:io';

import '../../sentry.dart';
import '../event_processor/enricher/flutter_runtime.dart';
import '../event_processor/enricher/io_platform_memory.dart';
import '../utils/os_utils.dart';
import 'platform_context_provider.dart';

PlatformContextProvider platformContextProvider(SentryOptions options) =>
    IoPlatformContextProvider(options);

class IoPlatformContextProvider implements PlatformContextProvider {
  IoPlatformContextProvider(this._options);

  final SentryOptions _options;
  late final SentryOperatingSystem _os = getSentryOperatingSystem();
  late final String _dartVersion = _extractDartVersion(Platform.version);
  bool _fetchedTotalPhysicalMemory = false;
  int? _totalPhysicalMemory;

  @override
  Future<Contexts> buildContexts() async {
    return Contexts(
      device: await _buildDevice(),
      operatingSystem: _buildOperatingSystem(),
      runtimes: _buildRuntimes(),
      app: _buildApp(),
      culture: _buildCulture(),
    );
  }

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
    return fullVersion.substring(0, match?.end);
  }

  Future<SentryDevice> _buildDevice() async {
    return SentryDevice(
      name: _options.sendDefaultPii ? Platform.localHostname : null,
      processorCount: Platform.numberOfProcessors,
      memorySize: await _getTotalPhysicalMemory(),
    );
  }

  Future<int?> _getTotalPhysicalMemory() async {
    if (!_fetchedTotalPhysicalMemory) {
      _totalPhysicalMemory =
          await PlatformMemory(_options).getTotalPhysicalMemory();
      _fetchedTotalPhysicalMemory = true;
    }
    return _totalPhysicalMemory;
  }

  SentryOperatingSystem _buildOperatingSystem() {
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
  }

  List<SentryRuntime> _buildRuntimes() {
    // Pure Dart doesn't have specific runtimes per build mode like Flutter:
    // https://flutter.dev/docs/testing/build-modes
    final dartRuntime = SentryRuntime(
      name: 'Dart',
      version: _dartVersion,
      rawDescription: Platform.version,
    );
    final flRuntime = flutterRuntime;
    return [dartRuntime, if (flRuntime != null) flRuntime];
  }

  SentryApp _buildApp() {
    return SentryApp(appMemory: ProcessInfo.currentRss);
  }

  SentryCulture _buildCulture() {
    return SentryCulture(
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
    );
  }
}
