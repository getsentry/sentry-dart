import 'dart:async';

import 'package:sentry/sentry.dart';
import '../native/sentry_native_binding.dart';

// ignore: invalid_use_of_internal_member
class NativeContextsEnricher implements ContextsEnricher {
  NativeContextsEnricher(this._native);

  final SentryNativeBinding _native;

  /// Avoid loading the infos multiple times from the native SDK.
  Map<String, dynamic>? cachedInfos;

  @override
  Future<void> enrich(Contexts contexts) async {
    final infos = await _native.loadContexts() ?? {};
    final contextsMap = infos['contexts'] as Map?;
    cachedInfos = infos;

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
}
