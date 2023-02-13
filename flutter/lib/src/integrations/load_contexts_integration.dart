import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

/// Load Device's Contexts from the iOS SDK.
///
/// This integration calls the iOS SDK via Message channel to load the
/// Device's contexts before sending the event back to the iOS SDK via
/// Message channel (already enriched with all the information).
///
/// The Device's contexts are:
/// App, Device and OS.
///
/// ps. This integration won't be run on Android because the Device's Contexts
/// is set on Android when the event is sent to the Android SDK via
/// the Message channel.
/// We intend to unify this behaviour in the future.
///
/// This integration is only executed on iOS & MacOS Apps.
class LoadContextsIntegration extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  LoadContextsIntegration(this._channel);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) async {
    options.addEventProcessor(
      _LoadContextsIntegrationEventProcessor(_channel, options),
    );
    options.sdk.addIntegration('loadContextsIntegration');
  }
}

class _LoadContextsIntegrationEventProcessor extends EventProcessor {
  _LoadContextsIntegrationEventProcessor(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {hint}) async {
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
                if (key == SentryOperatingSystem.type &&
                    currentValue is SentryOperatingSystem &&
                    value is SentryOperatingSystem) {
                  final osMap = {...value.toJson(), ...currentValue.toJson()};
                  final os = SentryOperatingSystem.fromJson(osMap);
                  eventContexts[key] = os;
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
        final extras = event.extra ?? {};
        final newExtras = Map<String, dynamic>.from(extraMap);

        for (final extra in newExtras.entries) {
          if (!extras.containsKey(extra.key)) {
            extras[extra.key] = extra.value;
          }
        }
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
      if (breadcrumbsList != null && breadcrumbsList.isNotEmpty) {
        final breadcrumbs = event.breadcrumbs ?? [];
        final breadcrumbsJson =
            breadcrumbs.map((breadcrumb) => breadcrumb.toJson());

        final newBreadcrumbs =
            List<Map<dynamic, dynamic>>.from(breadcrumbsList);

        for (final breadcrumb in newBreadcrumbs) {
          final newBreadcrumbJson = Map<String, dynamic>.from(breadcrumb);

          var containsDuplicate = false;
          for (final breadcrumbJson in breadcrumbsJson) {
            if (mapEquals(newBreadcrumbJson, breadcrumbJson)) {
              containsDuplicate = true;
              break;
            }
          }

          if (!containsDuplicate) {
            final newBreadcrumb = Breadcrumb.fromJson(newBreadcrumbJson);
            breadcrumbs.add(newBreadcrumb);
          }
        }

        breadcrumbs.sort((a, b) {
          return a.timestamp.compareTo(b.timestamp);
        });

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

      // on iOS, captureEnvelope does not call the beforeSend callback,
      // hence we need to add these tags here.
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
