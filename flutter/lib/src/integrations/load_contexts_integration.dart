import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

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
  final MethodChannel _channel;

  LoadContextsIntegration(this._channel);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadContextsIntegrationEventProcessor(_channel, options),
    );
    options.sdk.addIntegration('loadContextsIntegration');
  }
}

class _LoadContextsIntegrationEventProcessor implements EventProcessor {
  _LoadContextsIntegrationEventProcessor(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    try {
      final loadContexts = await _channel.invokeMethod('loadContexts');

      final infos =
          Map<String, dynamic>.from(loadContexts is Map ? loadContexts : {});
      final contextsMap = infos['contexts'] as Map?;
      if (contextsMap != null && contextsMap.isNotEmpty) {
        final contexts = Contexts.fromJson(
          Map<String, dynamic>.from(contextsMap),
        );
        final eventContexts = event.contexts.clone();

        contexts.forEach(
          (key, dynamic value) {
            if (value != null) {
              final currentValue = eventContexts[key];
              if (key == SentryRuntime.listType) {
                contexts.runtimes.forEach(eventContexts.addRuntime);
              } else if (currentValue == null) {
                eventContexts[key] = value;
              } else {
                // merge the values
                if (key == SentryOperatingSystem.type &&
                    currentValue is SentryOperatingSystem &&
                    value is SentryOperatingSystem) {
                  // merge os context
                  final osMap = {...value.toJson(), ...currentValue.toJson()};
                  final os = SentryOperatingSystem.fromJson(osMap);
                  eventContexts[key] = os;
                } else if (key == SentryApp.type &&
                    currentValue is SentryApp &&
                    value is SentryApp) {
                  // merge app context
                  final appMap = {...value.toJson(), ...currentValue.toJson()};
                  final app = SentryApp.fromJson(appMap);
                  eventContexts[key] = app;
                }
              }
            }
          },
        );
        event = event.copyWith(contexts: eventContexts);
      }

      final tagsMap = infos['tags'] as Map?;
      if (tagsMap != null && tagsMap.isNotEmpty) {
        final tags = event.tags ?? {};
        final newTags = Map<String, String>.from(tagsMap);

        for (final tag in newTags.entries) {
          if (!tags.containsKey(tag.key)) {
            tags[tag.key] = tag.value;
          }
        }
        event = event.copyWith(tags: tags);
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
        event = event.copyWith(extra: extras);
      }

      final userMap = infos['user'] as Map?;
      if (event.user == null && userMap != null && userMap.isNotEmpty) {
        final user = Map<String, dynamic>.from(userMap);
        event = event.copyWith(user: SentryUser.fromJson(user));
      }

      final distString = infos['dist'] as String?;
      if (event.dist == null && distString != null) {
        event = event.copyWith(dist: distString);
      }

      final environmentString = infos['environment'] as String?;
      if (event.environment == null && environmentString != null) {
        event = event.copyWith(environment: environmentString);
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
        event = event.copyWith(fingerprint: eventFingerprints);
      }

      final levelString = infos['level'] as String?;
      if (event.level == null && levelString != null) {
        event = event.copyWith(level: SentryLevel.fromName(levelString));
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

        event = event.copyWith(breadcrumbs: breadcrumbs);
      }

      final integrationsList = infos['integrations'] as List?;
      if (integrationsList != null && integrationsList.isNotEmpty) {
        final integrations = List<String>.from(integrationsList);
        final sdk = event.sdk ?? _options.sdk;

        for (final integration in integrations) {
          sdk.addIntegration(integration);
        }

        event = event.copyWith(sdk: sdk);
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

        event = event.copyWith(sdk: sdk);
      }

      // captureEnvelope does not call the beforeSend callback, hence we need to
      // add these tags here.
      if (event.sdk?.name == 'sentry.dart.flutter') {
        final tags = event.tags ?? {};
        tags['event.origin'] = 'flutter';
        tags['event.environment'] = 'dart';
        event = event.copyWith(tags: tags);
      }
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'loadContextsIntegration failed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
    return event;
  }
}
