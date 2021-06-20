import 'dart:async';
import 'dart:io';

import '../event_processor.dart';
import '../protocol.dart';
import '../sentry_options.dart';

EventProcessor enricherEventProcessor(SentryOptions options) {
  return IoEnricherEventProcessor(options);
}

/// Enriches [SentryEvents] with various kinds of information.
/// Uses Darts [Platform](https://api.dart.dev/stable/dart-io/Platform-class.html)
/// class to read information.
class IoEnricherEventProcessor extends EventProcessor {
  IoEnricherEventProcessor(
    this._options,
  );

  final SentryOptions _options;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event, {dynamic hint}) {
    // If there's a native integration available, it probably has better
    // information available than Flutter.
    final os = _options.platformChecker.hasNativeIntegration
        ? null
        : _getOperatingSystem(event.contexts.operatingSystem);
    final device = _options.platformChecker.hasNativeIntegration
        ? null
        : _getDevice(event.contexts.device);

    final contexts = event.contexts.copyWith(
      operatingSystem: os,
      device: device,
      runtimes: _getRuntimes(event.contexts.runtimes),
    );

    contexts['dart_context'] = _getDartContext(_options.sendDefaultPii);

    return event.copyWith(
      contexts: contexts,
    );
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    // Pure Dart doesn't have specific runtimes per build mode
    // like Flutter: https://flutter.dev/docs/testing/build-modes
    final dartRuntime = SentryRuntime(
      key: 'sentry_dart_runtime',
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

  Map<String, dynamic> _getDartContext(bool includePii) {
    final args = Platform.executableArguments;
    final packageConfig = Platform.packageConfig;

    String? executable;
    if (includePii) {
      try {
        // This throws sometimes for some reason
        // https://github.com/flutter/flutter/issues/83921
        executable = Platform.executable;
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.info,
          'Platform.executable couldn\'t be retrieved.',
          error: exception,
          stackTrace: stackTrace,
        );
      }
    }

    return <String, dynamic>{
      if (packageConfig != null) 'package_config': packageConfig,
      'number_of_processors': Platform.numberOfProcessors,
      // The following information could potentially contain PII
      if (includePii) ...{
        'executable': executable,
        'resolved_executable': Platform.resolvedExecutable,
        'script': Platform.script.toString(),
        if (args.isNotEmpty)
          'executable_arguments': Platform.executableArguments,
      },
    };
  }

  SentryDevice _getDevice(SentryDevice? device) {
    return (device ?? SentryDevice()).copyWith(
      language: device?.language ?? Platform.localeName,
      name: device?.name ?? Platform.localHostname,
      timezone: device?.timezone ?? DateTime.now().timeZoneName,
    );
  }

  SentryOperatingSystem _getOperatingSystem(SentryOperatingSystem? os) {
    return (os ?? SentryOperatingSystem()).copyWith(
      name: os?.name ?? Platform.operatingSystem,
      version: os?.version ?? Platform.operatingSystemVersion,
    );
  }
}
