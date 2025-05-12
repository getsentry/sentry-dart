@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/web/debug_ids.dart';
import 'package:sentry_flutter/src/web/script_loader/sentry_script_loader.dart';
import 'package:sentry_flutter/src/web/sentry_js_bundle.dart';
import 'package:sentry_flutter/src/web/web_sentry_js_binding.dart';

import '../mocks.dart';

/// Test file for testing specific binding implementation such as caching.
/// Most of the other tests that involve the binding live in sentry_web_test.dart.
void main() {
  group(WebSentryJsBinding, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
        'getFilenameToDebugIdMap returns the cached result on subsequent calls',
        () async {
      final sut = await fixture.getSut();
      sut.init({});
      _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

      final firstResult = sut.getFilenameToDebugIdMap();
      final cachedResult = filenameToDebugIds;
      final secondResult = sut.getFilenameToDebugIdMap();

      expect(firstResult, isNotNull);
      expect(firstResult, cachedResult);
      expect(secondResult, cachedResult);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  Future<WebSentryJsBinding> getSut() async {
    final loader = SentryScriptLoader(options: options);
    await loader.loadWebSdk(debugScripts);
    return WebSentryJsBinding();
  }
}

@JS('globalThis')
external JSObject get _globalThis;
