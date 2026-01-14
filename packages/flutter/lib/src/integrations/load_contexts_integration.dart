// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:collection/collection.dart';
import 'package:sentry/src/event_processor/enricher/enricher_event_processor.dart';
import 'package:sentry/src/logs_enricher_integration.dart';
import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';
import '../telemetry/enricher/native_contexts_attributes_provider.dart';

/// Load Device's Contexts from the iOS & Android SDKs.
///
/// This integration calls the iOS & Android SDKs via Message channel to load
/// the Device's contexts before sending the event back to the SDK via
/// Message channel (already enriched with all the information).
///
/// The Device's contexts are:
/// App, Device and OS.
///
/// This integration is only executed on iOS, macOS & Android Apps.
class LoadContextsIntegration extends Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;

  LoadContextsIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadContextsIntegrationEventProcessor(_native, options),
    );

    // TODO(next-pr): replace logs enriching with new enricher
    options.globalTelemetryEnricher.registerAttributesProvider(
        NativeContextsTelemetryAttributesProvider(_native));

    // We need to move [IOEnricherEventProcessor] after [_LoadContextsIntegrationEventProcessor]
    // so that we know which contexts were set by the user and which were set by the other processor.
    // The priorities are:
    // - user-set context values
    // - context values set from native (this)
    // - values set from IOEnricherEventProcessor
    final enricherEventProcessor = options.eventProcessors.firstWhereOrNull(
      (element) => element is EnricherEventProcessor,
    );
    if (enricherEventProcessor != null) {
      options.removeEventProcessor(enricherEventProcessor);
      options.addEventProcessor(enricherEventProcessor);
    }
    if (options.enableLogs) {
      final logsEnricherIntegration = options.integrations.firstWhereOrNull(
        (element) => element is LogsEnricherIntegration,
      );
      if (logsEnricherIntegration != null) {
        // Contexts from native cover the os.name and os.version attributes,
        // so we can remove the logsEnricherIntegration.
        options.removeIntegration(logsEnricherIntegration);
      }

      options.lifecycleRegistry.registerCallback<OnBeforeCaptureLog>(
        (event) async {
          try {
            final infos = await _native.loadContexts() ?? {};

            final contextsMap = infos['contexts'] as Map?;
            final contexts =
                Contexts(); // We just need the the native contexts.
            _mergeNativeWithLocalContexts(contextsMap, contexts);

            if (contexts.operatingSystem?.name != null) {
              event.log.attributes['os.name'] = SentryAttribute.string(
                contexts.operatingSystem?.name ?? '',
              );
            }
            if (contexts.operatingSystem?.version != null) {
              event.log.attributes['os.version'] = SentryAttribute.string(
                contexts.operatingSystem?.version ?? '',
              );
            }
            if (contexts.device?.brand != null) {
              event.log.attributes['device.brand'] = SentryAttribute.string(
                contexts.device?.brand ?? '',
              );
            }
            if (contexts.device?.model != null) {
              event.log.attributes['device.model'] = SentryAttribute.string(
                contexts.device?.model ?? '',
              );
            }
            if (contexts.device?.family != null) {
              event.log.attributes['device.family'] = SentryAttribute.string(
                contexts.device?.family ?? '',
              );
            }
          } catch (exception, stackTrace) {
            options.log(
              SentryLevel.error,
              'LoadContextsIntegration failed to load contexts',
              exception: exception,
              stackTrace: stackTrace,
            );
          }
        },
      );
    }
    options.sdk.addIntegration('loadContextsIntegration');
  }
}

class _LoadContextsIntegrationEventProcessor implements EventProcessor {
  _LoadContextsIntegrationEventProcessor(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryFlutterOptions _options;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    // TODO don't copy everything (i.e. avoid unnecessary Map.from())
    try {
      final infos = await _native.loadContexts() ?? {};
      final contextsMap = infos['contexts'] as Map?;
      _mergeNativeWithLocalContexts(contextsMap, event.contexts);

      final tagsMap = infos['tags'] as Map?;
      if (tagsMap != null && tagsMap.isNotEmpty) {
        final tags = event.tags ?? {};
        final newTags = Map<String, String>.from(tagsMap);

        for (final tag in newTags.entries) {
          if (!tags.containsKey(tag.key)) {
            tags[tag.key] = tag.value;
          }
        }
        event.tags = tags;
      }

      final extraMap = infos['extra'] as Map?;
      if (extraMap != null && extraMap.isNotEmpty) {
        // ignore: deprecated_member_use
        final extras = event.extra ?? {};
        final newExtras = Map<String, dynamic>.from(extraMap);

        for (final extra in newExtras.entries) {
          if (!extras.containsKey(extra.key)) {
            extras[extra.key] = extra.value;
          }
        }

        // ignore: deprecated_member_use
        event.extra = extras;
      }

      final userMap = infos['user'] as Map?;
      if (event.user == null && userMap != null && userMap.isNotEmpty) {
        final user = Map<String, dynamic>.from(userMap);
        event.user = SentryUser.fromJson(user);
      }

      final distString = infos['dist'] as String?;
      if (event.dist == null && distString != null) {
        event.dist = distString;
      }

      final environmentString = infos['environment'] as String?;
      if (event.environment == null && environmentString != null) {
        event.environment = environmentString;
      }

      final fingerprintList = infos['fingerprint'] as List?;
      if (fingerprintList != null && fingerprintList.isNotEmpty) {
        final eventFingerprints = event.fingerprint ?? [];
        final newFingerprint = List<String>.from(fingerprintList);

        for (final fingerprint in newFingerprint) {
          if (!eventFingerprints.contains(fingerprint)) {
            eventFingerprints.add(fingerprint);
          }
        }
        event.fingerprint = eventFingerprints;
      }

      final levelString = infos['level'] as String?;
      if (event.level == null && levelString != null) {
        event.level = SentryLevel.fromName(levelString);
      }

      final breadcrumbsList = infos['breadcrumbs'] as List?;
      if (breadcrumbsList != null &&
          breadcrumbsList.isNotEmpty &&
          _options.enableScopeSync) {
        final breadcrumbsJson =
            List<Map<dynamic, dynamic>>.from(breadcrumbsList);
        final breadcrumbs = <Breadcrumb>[];
        final beforeBreadcrumb = _options.beforeBreadcrumb;

        for (final breadcrumbJson in breadcrumbsJson) {
          final breadcrumb = Breadcrumb.fromJson(
            Map<String, dynamic>.from(breadcrumbJson),
          );

          if (beforeBreadcrumb != null) {
            final processedBreadcrumb = beforeBreadcrumb(breadcrumb, Hint());
            if (processedBreadcrumb != null) {
              breadcrumbs.add(processedBreadcrumb);
            }
          } else {
            breadcrumbs.add(breadcrumb);
          }
        }

        event.breadcrumbs = breadcrumbs;
      }

      final integrationsList = infos['integrations'] as List?;
      if (integrationsList != null && integrationsList.isNotEmpty) {
        final integrations = List<String>.from(integrationsList);
        final sdk = event.sdk ?? _options.sdk;

        for (final integration in integrations) {
          sdk.addIntegration(integration);
        }

        event.sdk = sdk;
      }

      final packageMap = infos['package'] as Map?;
      if (packageMap != null && packageMap.isNotEmpty) {
        final package = Map<String, String>.from(packageMap);
        final sdk = event.sdk ?? _options.sdk;

        final name = package['sdk_name'];
        final version = package['version'];
        if (name != null &&
            version != null &&
            !sdk.packages.any((element) =>
                element.name == name && element.version == version)) {
          sdk.addPackage(name, version);
        }

        event.sdk = sdk;
      }

      // captureEnvelope does not call the beforeSend callback, hence we need to
      // add these tags here.
      if (event.sdk?.name == 'sentry.dart.flutter') {
        final tags = event.tags ?? {};
        tags['event.origin'] = 'flutter';
        tags['event.environment'] = 'dart';
        event.tags = tags;
      }
    } catch (exception, stackTrace) {
      _options.log(
        SentryLevel.error,
        'loadContextsIntegration failed',
        exception: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
    return event;
  }
}

@internal
void mergeNativeWithLocalContexts(
        Map<dynamic, dynamic>? contextsMap, Contexts contexts) =>
    _mergeNativeWithLocalContexts(contextsMap, contexts);

void _mergeNativeWithLocalContexts(
    Map<dynamic, dynamic>? contextsMap, Contexts contexts) {
  if (contextsMap != null && contextsMap.isNotEmpty) {
    final nativeContexts = Contexts.fromJson(
      Map<String, dynamic>.from(contextsMap),
    );

    nativeContexts.forEach(
      (key, dynamic value) {
        if (value != null) {
          final currentValue = contexts[key];
          if (key == SentryRuntime.listType) {
            nativeContexts.runtimes.forEach(contexts.addRuntime);
          } else if (currentValue == null) {
            contexts[key] = value;
          } else {
            // merge the values
            if (key == SentryOperatingSystem.type &&
                currentValue is SentryOperatingSystem &&
                value is SentryOperatingSystem) {
              // merge os context
              final osMap = {...value.toJson(), ...currentValue.toJson()};
              final os = SentryOperatingSystem.fromJson(osMap);
              contexts[key] = os;
            } else if (key == SentryApp.type &&
                currentValue is SentryApp &&
                value is SentryApp) {
              // merge app context
              final appMap = {...value.toJson(), ...currentValue.toJson()};
              final app = SentryApp.fromJson(appMap);
              contexts[key] = app;
            }
          }
        }
      },
    );
  }
}
