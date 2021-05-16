import 'dart:async';
import 'dart:io';

import '../protocol.dart';

import 'enricher.dart';

final Enricher instance = IoEnricher();

/// Enriches [SentryEvents] with various kinds of information.
/// Uses Darts [Platform](https://api.dart.dev/stable/dart-io/Platform-class.html)
/// class to read information.
class IoEnricher implements Enricher {
  @override
  FutureOr<SentryEvent> apply(SentryEvent event, bool hasNativeIntegration) {
    // If there's a native integration available, it probably has better
    // information available than Flutter.
    final os = hasNativeIntegration
        ? null
        : _getOperatingSystem(event.contexts.operatingSystem);
    final device =
        hasNativeIntegration ? null : _getDevice(event.contexts.device);

    final contexts = event.contexts.copyWith(
      operatingSystem: os,
      device: device,
      runtimes: _getRuntimes(event.contexts.runtimes),
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

    return <String, dynamic>{
      if (packageConfig != null) 'package_config': packageConfig,
      'number_of_processors': Platform.numberOfProcessors,
      // The following information could potentially contain PII
      // 'executable': Platform.executable, // this throws sometimes for some reason
      'resolved_executable': Platform.resolvedExecutable,
      'script': Platform.script.toString(),
      if (args.isNotEmpty) 'executable_arguments': Platform.executableArguments,
    };
  }

  SentryDevice _getDevice(SentryDevice? device) {
    return (device ?? SentryDevice()).copyWith(
      language: Platform.localeName,
      name: Platform.localHostname,
      timezone: DateTime.now().timeZoneName,
    );
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    return (os ?? SentryOperatingSystem()).copyWith(
      name: Platform.operatingSystem,
      version: Platform.operatingSystemVersion,
    );
  }
}
