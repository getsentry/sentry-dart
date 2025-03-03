import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../sentry_js_bundle.dart';
import 'script_dom_api.dart';

@internal
const String defaultTrustedPolicyName = 'sentry-dart';

class SentryScriptLoader {
  SentryScriptLoader({SentryOptions? options})
      :
        // ignore: invalid_use_of_internal_member
        _options = options ?? Sentry.currentHub.options;

  final SentryOptions _options;
  bool _scriptLoaded = false;

  /// Loads the scripts into the web page with support for Trusted Types security policy.
  ///
  /// The function handles three Trusted Types scenarios:
  /// 1. No Trusted Types configured - Scripts load normally
  /// 2. Custom Trusted Types policy - Uses provided policy name to create trusted URLs
  /// 3. Trusted Types forbidden - Scripts are not loaded
  ///
  /// The function is only executed successfully once and will be guarded by a flag afterwards.
  ///
  /// TrustedTypes implementation inspired by https://pub.dev/packages/google_identity_services_web
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
    } catch (e) {
      _options.logger(SentryLevel.error, 'Failed to load Sentry scripts: $e');
      // ignore: invalid_use_of_internal_member
      if (_options.automatedTestMode) {
        rethrow;
      }
    }
  }

  Future<void> close() async {
    final scriptsToRemove = _options.runtimeChecker.isReleaseMode()
        ? productionScripts
        : debugScripts;

    // no risk of injection since the scripts are constants
    final selectors = scriptsToRemove.map((script) {
      return 'script[src="${script['url']}"][integrity="${script['integrity']}"]';
    }).join(', ');
    final sentryScripts = fetchScripts(selectors);
    for (final script in sentryScripts) {
      script.remove();
    }
  }
}

/// Exception thrown if the Trusted Types feature is supported, enabled, and it
/// has prevented this loader from injecting the Sentry JS SDK
@internal
class TrustedTypesException implements Exception {
  TrustedTypesException();
}
