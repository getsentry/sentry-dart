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
  FutureOr<SentryEvent> apply(SentryEvent event) {
    final contexts = event.contexts.copyWith(
      operatingSystem: _getOperatingSystem(event.contexts.operatingSystem),
      device: _getDevice(event.contexts.device),
      runtimes: _getRuntimes(event.contexts.runtimes),
    );

    return event.copyWith(
      contexts: contexts,
      extra: _getExtras(event.extra),
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    final dartRuntime = SentryRuntime(name: 'Dart', version: Platform.version);
    if (runtimes == null) {
      return [dartRuntime];
    }
    return [
      ...runtimes,
      dartRuntime,
    ];
  }

  Map<String, dynamic> _getExtras(Map<String, dynamic>? extras) {
    final args = Platform.executableArguments;
    final packageConfig = Platform.packageConfig;
    final cpuCount = Platform.numberOfProcessors;

    final moreExtras = <String, dynamic>{
      if (args.isNotEmpty) 'executableArguments': Platform.executableArguments,
      if (packageConfig != null) 'packageConfig': packageConfig,
      'numberOfProcessors': cpuCount,
    };

    if (extras == null) {
      return moreExtras;
    }
    extras.addAll(moreExtras);
    return extras;
  }

  SentryDevice _getDevice(SentryDevice? device) {
    return (device ?? SentryDevice()).copyWith(
      language: Platform.localeName,
      // this is the Name given to the device by the user of the device
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
