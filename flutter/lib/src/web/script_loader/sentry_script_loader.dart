import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import 'script_dom_api.dart';

@internal
class SentryScriptLoader {
  SentryScriptLoader(this.options, this.scripts);

  final SentryFlutterOptions options;
  final List<Map<String, String>> scripts;
  bool _scriptLoaded = false;

  /// Loads scripts into the document asynchronously.
  ///
  /// Idempotent: does nothing if scripts are already loaded.
  Future<void> load() async {
    if (_scriptLoaded) return;

    try {
      await Future.wait(scripts.map((script) async {
        final url = script['url'];
        final integrity = script['integrity'];

        if (url != null) {
          return loadScript(url, integrity);
        }
      }));
      _scriptLoaded = true;
      options.logger(SentryLevel.debug,
          'JS SDK integration: all Sentry scripts loaded successfully.');
    } catch (e, stackTrace) {
      options.logger(
          SentryLevel.error, 'Failed to load Sentry scripts: $e\n$stackTrace');
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }
}
