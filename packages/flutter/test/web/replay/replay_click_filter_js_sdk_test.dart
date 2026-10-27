@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_binding.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/web_sentry_js_binding.dart';
import 'package:web/web.dart' as web;

import '../../mocks.dart';

/// Feeds a real JS SDK click breadcrumb through the filter, guarding against
/// the JS SDK or rrweb changing the event shape it matches on, which
/// hand-built events can't catch.
///
/// Lives in its own file so the page loads the JS SDK only once: every
/// loaded bundle adds a document click listener, and the first one marks the
/// event as captured, so later bundles never see the click.
void main() {
  group('isFlutterViewClickEvent with the JS SDK', () {
    test('drops the flutter-view DOM click breadcrumb', () async {
      final binding = await _loadSdk();
      binding.init({
        'dsn': fakeDsn,
        'replaysSessionSampleRate': 1.0,
        'integrations': [SentryJsIntegrationName.replay],
      });
      addTearDown(binding.close);

      final replay = _getReplay()!['_replay'] as JSObject;
      await _waitUntil(
        () => replay.callMethod<JSBoolean>('isEnabled'.toJS).toDart,
      );
      final clickResult = _interceptFlutterViewClick(replay);

      final flutterView = web.document.createElement('flutter-view');
      web.document.body!.append(flutterView);
      addTearDown(() => flutterView.remove());
      // rrweb only describes nodes its MutationObserver has registered.
      await Future<void>.delayed(Duration.zero);
      flutterView.dispatchEvent(
        web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
      );

      expect(await clickResult.timeout(const Duration(seconds: 5)), isNull);
    });
  });
}

Future<WebSentryJsBinding> _loadSdk() async {
  final loader = SentryScriptLoader(options: defaultTestOptions());
  await loader.loadWebSdk(debugReplayScripts);
  return WebSentryJsBinding();
}

/// Completes with what the SDK's `beforeAddRecordingEvent` returns for the
/// first `ui.click` breadcrumb on a `<flutter-view>`.
Future<JSAny?> _interceptFlutterViewClick(JSObject replay) {
  final options = replay.callMethod<JSObject>('getOptions'.toJS);
  final original = options['beforeAddRecordingEvent'] as JSFunction;
  final result = Completer<JSAny?>();
  options['beforeAddRecordingEvent'] = ((JSAny? event) {
    final filtered = original.callAsFunction(null, event);
    final json = _jsonStringify(event).toDart;
    if (!result.isCompleted &&
        json.contains('"ui.click"') &&
        json.contains('flutter-view')) {
      result.complete(filtered);
    }
    return filtered;
  }).toJS;
  return result.future;
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

@JS('Sentry.getReplay')
external JSObject? _getReplay();

@JS('JSON.stringify')
external JSString _jsonStringify(JSAny? value);
