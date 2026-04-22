import 'dart:io';

import '../../../sentry.dart';
import '../../platform/platform_context_provider.dart';
import 'enricher_event_processor.dart';

EnricherEventProcessor enricherEventProcessor(
  SentryOptions options,
  PlatformContextProvider provider,
) {
  return IoEnricherEventProcessor(options, provider);
}

/// Enriches [SentryEvent]s with various kinds of information.
///
/// Platform detection is delegated to [PlatformContextProvider]; this
/// processor is responsible for merging the detected data into
/// `event.contexts` while preserving user-supplied values.
class IoEnricherEventProcessor implements EnricherEventProcessor {
  IoEnricherEventProcessor(this._options, this._provider);

  final SentryOptions _options;
  final PlatformContextProvider _provider;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final platform = await _provider.buildContexts();

    event.contexts
      ..device = _mergeDevice(event.contexts.device, platform.device)
      ..operatingSystem =
          _mergeOperatingSystem(event.contexts.operatingSystem, platform)
      ..runtimes = _mergeRuntimes(event.contexts.runtimes, platform.runtimes)
      ..app = _mergeApp(event.contexts.app, platform.app)
      ..culture = _mergeCulture(event.contexts.culture, platform.culture);

    event.contexts['dart_context'] = _getDartContext();
    return event;
  }

  SentryDevice _mergeDevice(SentryDevice? existing, SentryDevice? detected) {
    existing ??= SentryDevice();
    return existing
      ..name = existing.name ?? detected?.name
      ..processorCount = existing.processorCount ?? detected?.processorCount
      ..memorySize = existing.memorySize ?? detected?.memorySize
      ..freeMemory = existing.freeMemory;
  }

  SentryOperatingSystem _mergeOperatingSystem(
      SentryOperatingSystem? existing, Contexts platform) {
    final detected = platform.operatingSystem;
    if (existing == null) {
      return detected ?? SentryOperatingSystem();
    }
    return detected?.mergeWith(existing) ?? existing;
  }

  List<SentryRuntime> _mergeRuntimes(
      List<SentryRuntime> existing, List<SentryRuntime> detected) {
    return [...existing, ...detected];
  }

  SentryApp _mergeApp(SentryApp? existing, SentryApp? detected) {
    existing ??= SentryApp();
    return existing..appMemory = existing.appMemory ?? detected?.appMemory;
  }

  SentryCulture _mergeCulture(
      SentryCulture? existing, SentryCulture? detected) {
    existing ??= SentryCulture();
    return existing
      ..locale = existing.locale ?? detected?.locale
      ..timezone = existing.timezone ?? detected?.timezone;
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
}
