import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../../protocol.dart';
import '../../sentry_options.dart';
import 'enricher_event_processor.dart';

EnricherEventProcessor enricherEventProcessor(SentryOptions options) {
  return IoEnricherEventProcessor(options);
}

/// Enriches [SentryEvents] with various kinds of information.
/// Uses Darts [Platform](https://api.dart.dev/stable/dart-io/Platform-class.html)
/// class to read information.
class IoEnricherEventProcessor implements EnricherEventProcessor {
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

    final culture = _options.platformChecker.hasNativeIntegration
        ? null
        : _getSentryCulture(event.contexts.culture);

    final contexts = event.contexts.copyWith(
      operatingSystem: os,
      device: device,
      runtimes: _getRuntimes(event.contexts.runtimes),
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

  Map<String, dynamic> _getDartContext() {
    final args = Platform.executableArguments;
    final packageConfig = Platform.packageConfig;
    final isolate = Isolate.current.debugName;

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
      }
    }

    return <String, dynamic>{
      'compile_mode': _options.platformChecker.compileMode,
      if (packageConfig != null) 'package_config': packageConfig,
      // should be moved to event.thread.name
      if (isolate != null) 'isolate': isolate,
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
    return (device ?? SentryDevice()).copyWith(
      name: device?.name ?? Platform.localHostname,
      processorCount: device?.processorCount ?? Platform.numberOfProcessors,
      // ignore: deprecated_member_use_from_same_package
      language: device?.language ?? Platform.localeName,
      // ignore: deprecated_member_use_from_same_package
      timezone: device?.timezone ?? DateTime.now().timeZoneName,
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
