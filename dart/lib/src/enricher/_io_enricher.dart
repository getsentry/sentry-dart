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
    final locale = Platform.localeName;
    final localHostname = Platform.localHostname;
    // TODO What about:
    // Platform.executeable
    // Platform.resolvedExecuteable
    // Platform.pathSeperator

    final moreExtras = <String, dynamic>{
      if (args.isNotEmpty) 'executableArguments': Platform.executableArguments,
      if (packageConfig != null) 'packageConfig': packageConfig,
      'numberOfProcessors': cpuCount,
      'localName': locale,
      'hostname': localHostname,
    };

    if (extras == null) {
      return moreExtras;
    }
    extras.addAll(moreExtras);
    return extras;
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    if (os == null) {
      return SentryOperatingSystem(
        name: Platform.operatingSystem,
        version: Platform.operatingSystemVersion,
      );
    } else {
      return os.copyWith(
        name: Platform.operatingSystem,
        version: Platform.operatingSystemVersion,
      );
    }
  }
}
