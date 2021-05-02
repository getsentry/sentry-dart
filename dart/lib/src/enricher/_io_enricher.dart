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
  FutureOr<void> apply(SentryEvent event) {
    final contexts = event.contexts.copyWith(
      operatingSystem: _getOperatingSystem(event.contexts.operatingSystem),
    );

    return event.copyWith(
      contexts: contexts,
      extra: _getExtras(event.extra),
    );
  }

  Map<String, dynamic> _getExtras(Map<String, dynamic>? extras) {
    final args = Platform.executableArguments;
    final packageConfig = Platform.packageConfig;
    final cpuCount = Platform.numberOfProcessors;
    final environment = Platform.environment;
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
      if (environment.isNotEmpty) 'environment': environment,
      'localName': locale,
      'localHostname': localHostname,
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
