import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
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
      _globalThis['_sentryDebugIds'] = _debugIdMap.jsify();

      final firstResult = sut.getFilenameToDebugIdMap();
      final cachedResult = sut.cachedFilenameDebugIds;
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

final _debugId = '82cc8a97-04c5-5e1e-b98d-bb3e647208e6';
final _firstFrame =
    '''Error at chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/inline/injected/webauthn-listeners.js:2:127
  at chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/inline/injected/webauthn-listeners.js:2:260
''';
final _secondFrame = '''Error at http://127.0.0.1:8080/main.dart.js:2:169
  at http://127.0.0.1:8080/main.dart.js:2:304''';
// We wanna assert that the second frame is the correct debug id match
final _debugIdMap = {_firstFrame: 'whatever debug id', _secondFrame: _debugId};

@JS('globalThis')
external JSObject get _globalThis;
