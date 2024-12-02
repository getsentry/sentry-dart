import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import 'script_dom_api.dart';

@internal
const String defaultTrustedPolicyName = 'sentry-dart';

class SentryScriptLoader {
  SentryScriptLoader(this._options);

  final SentryFlutterOptions _options;
  bool _scriptLoaded = false;

  /// Loads scripts into the document asynchrcriptLoader {
  ///
  /// Idempotent: does nothing if scripts are already loaded.
  Future<void> loadWebSdk(List<Map<String, String>> scripts,
      {String trustedTypePolicyName = defaultTrustedPolicyName}) async {
    if (_scriptLoaded) return;

    try {
      await Future.forEach(scripts, (Map<String, String> script) async {
        final url = script['url'];
        final integrity = script['integrity'];

        if (url != null) {
          await loadScript(url, _options,
              integrity: integrity,
              trustedTypePolicyName: trustedTypePolicyName);
        }
      });

      _scriptLoaded = true;
      _options.logger(SentryLevel.debug,
          'JS SDK integration: all Sentry scripts loaded successfully.');
    } catch (e, stackTrace) {
      _options.logger(
          SentryLevel.error, 'Failed to load Sentry scripts: $e\n$stackTrace');
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
  }
}

/// Exception thrown if the Trusted Types feature is supported, enabled, and it
/// has prevented this loader from injecting the Sentry JS SDK
@visibleForTesting
class TrustedTypesException implements Exception {
  TrustedTypesException();
}
