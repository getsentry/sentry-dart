// ignore_for_file: implementation_imports, invalid_use_of_internal_member, experimental_member_use

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/enricher/enricher_event_processor.dart';
import 'package:sentry/src/protocol/access_aware_map.dart';
import 'package:sentry/src/telemetry/default_attributes.dart';
import 'package:sentry/src/utils/iterable_utils.dart';
import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';
import '../utils/internal_logger.dart';

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
class LoadContextsIntegration implements Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;
  Map<String, SentryAttribute>? _cachedAttributes;
  SentryFlutterOptions? _options;
  SdkLifecycleCallback<OnProcessLog>? _logCallback;
  SdkLifecycleCallback<OnProcessMetric>? _metricCallback;
  SdkLifecycleCallback<OnProcessSpan>? _spanCallback;

  LoadContextsIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    _options = options;

    options.addEventProcessor(
      _LoadContextsIntegrationEventProcessor(_native, options),
    );

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
      _logCallback = (event) async {
        try {
          final attributes = await _cachedSessionAttributes();
          event.log.attributes.addAllIfAbsent(attributes);
        } catch (exception, stackTrace) {
          internalLogger.error(
            'LoadContextsIntegration failed to load contexts for $OnProcessLog',
            error: exception,
            stackTrace: stackTrace,
          );
        }
      };
      options.lifecycleRegistry.registerCallback<OnProcessLog>(_logCallback!);
    }

    if (options.enableMetrics) {
      _metricCallback = (event) async {
        try {
          final attributes = await _cachedSessionAttributes();
          event.metric.attributes.addAllIfAbsent(attributes);
        } catch (exception, stackTrace) {
          internalLogger.error(
            'LoadContextsIntegration failed to load contexts for $OnProcessMetric',
            error: exception,
            stackTrace: stackTrace,
          );
        }
      };
      options.lifecycleRegistry.registerCallback<OnProcessMetric>(
        _metricCallback!,
      );
    }

    if (options.traceLifecycle == SentryTraceLifecycle.stream) {
      _spanCallback = (event) async {
        try {
          final span = event.span;
          final attributes = identical(span, span.segmentSpan)
              ? await _freshSegmentAttributes()
              : await _cachedSessionAttributes();
          span.setAttributesIfAbsent(attributes);
        } catch (exception, stackTrace) {
          internalLogger.error(
            'LoadContextsIntegration failed to load contexts for $OnProcessSpan',
            error: exception,
            stackTrace: stackTrace,
          );
        }
      };
      options.lifecycleRegistry.registerCallback<OnProcessSpan>(_spanCallback!);
    }

    options.sdk.addIntegration('loadContextsIntegration');
  }

  @override
  void close() {
    final options = _options;
    if (options == null) return;

    if (_logCallback != null) {
      options.lifecycleRegistry.removeCallback<OnProcessLog>(_logCallback!);
      _logCallback = null;
    }
    if (_metricCallback != null) {
      options.lifecycleRegistry.removeCallback<OnProcessMetric>(
        _metricCallback!,
      );
      _metricCallback = null;
    }
    if (_spanCallback != null) {
      options.lifecycleRegistry.removeCallback<OnProcessSpan>(_spanCallback!);
      _spanCallback = null;
    }
    _cachedAttributes = null;
  }

  Future<Map<String, SentryAttribute>> _cachedSessionAttributes() async {
    final cached = _cachedAttributes;
    if (cached != null) {
      return cached;
    }

    final contexts = await _loadNativeContexts();
    final attributes = contexts.toMinimalAttributes();

    _cachedAttributes = attributes;
    return attributes;
  }

  Future<Map<String, SentryAttribute>> _freshSegmentAttributes() async {
    final contexts = await _loadNativeContexts();
    return contexts.toAttributes();
  }

  Future<Contexts> _loadNativeContexts() async {
    final nativeContexts = AccessAwareMap(await _native.loadContexts() ?? {});
    final contexts = Contexts();
    _mergeNativeWithLocalContexts(nativeContexts.readMap('contexts'), contexts);
    return contexts;
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
      final infos = AccessAwareMap(await _native.loadContexts() ?? {});
      _mergeNativeWithLocalContexts(infos.readMap('contexts'), event.contexts);

      final tagsMap = infos.readStringMap('tags');
      if (tagsMap != null && tagsMap.isNotEmpty) {
        final tags = event.tags ?? {};

        for (final tag in tagsMap.entries) {
          if (!tags.containsKey(tag.key)) {
            tags[tag.key] = tag.value;
          }
        }
        event.tags = tags;
      }

      final extraMap = infos.readMap('extra');
      if (extraMap != null && extraMap.isNotEmpty) {
        // ignore: deprecated_member_use
        final extras = event.extra ?? {};

        for (final extra in extraMap.entries) {
          if (!extras.containsKey(extra.key)) {
            extras[extra.key] = extra.value;
          }
        }

        // ignore: deprecated_member_use
        event.extra = extras;
      }

      final userMap = infos.readMap('user');
      if (event.user == null && userMap != null && userMap.isNotEmpty) {
        event.user = SentryUser.fromJson(userMap);
      }

      final distString = infos.readString('dist');
      if (event.dist == null && distString != null) {
        event.dist = distString;
      }

      final environmentString = infos.readString('environment');
      if (event.environment == null && environmentString != null) {
        event.environment = environmentString;
      }

      final fingerprintList = infos.readStringList('fingerprint');
      if (fingerprintList != null && fingerprintList.isNotEmpty) {
        final eventFingerprints = event.fingerprint ?? [];

        for (final fingerprint in fingerprintList) {
          if (!eventFingerprints.contains(fingerprint)) {
            eventFingerprints.add(fingerprint);
          }
        }
        event.fingerprint = eventFingerprints;
      }

      final levelString = infos.readString('level');
      if (event.level == null && levelString != null) {
        event.level = SentryLevel.fromName(levelString);
      }

      final breadcrumbsJson = infos.readMapList('breadcrumbs');
      if (breadcrumbsJson != null &&
          breadcrumbsJson.isNotEmpty &&
          _options.enableScopeSync) {
        final breadcrumbs = <Breadcrumb>[];
        final beforeBreadcrumb = _options.beforeBreadcrumb;

        for (final breadcrumbJson in breadcrumbsJson) {
          final breadcrumb = Breadcrumb.fromJson(breadcrumbJson);

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

      final integrationsList = infos.readStringList('integrations');
      if (integrationsList != null && integrationsList.isNotEmpty) {
        final sdk = event.sdk ?? _options.sdk;

        for (final integration in integrationsList) {
          sdk.addIntegration(integration);
        }

        event.sdk = sdk;
      }

      final featuresList = infos.readStringList('features');
      if (featuresList != null && featuresList.isNotEmpty) {
        final sdk = event.sdk ?? _options.sdk;

        for (final feature in featuresList) {
          sdk.addFeature(feature);
        }

        event.sdk = sdk;
      }

      final package = infos.readStringMap('package');
      if (package != null && package.isNotEmpty) {
        final sdk = event.sdk ?? _options.sdk;

        final name = package['sdk_name'];
        final version = package['version'];
        if (name != null &&
            version != null &&
            !sdk.packages.any(
              (element) => element.name == name && element.version == version,
            )) {
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
      internalLogger.error(
        'loadContextsIntegration failed',
        error: exception,
        stackTrace: stackTrace,
      );
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
    return event;
  }
}

void _mergeNativeWithLocalContexts(
  Map<String, dynamic>? contextsMap,
  Contexts contexts,
) {
  if (contextsMap != null && contextsMap.isNotEmpty) {
    final nativeContexts = Contexts.fromJson(contextsMap);

    nativeContexts.forEach((key, dynamic value) {
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
    });
  }
}
