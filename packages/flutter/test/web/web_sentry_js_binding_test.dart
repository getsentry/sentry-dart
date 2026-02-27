@TestOn('browser')
library;

import 'dart:async';
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
      _globalThis['_sentryDebugIds'] = debugIdMap.jsify();

      final firstResult = sut.getFilenameToDebugIdMap();
      final cachedResult = sut.filenameToDebugIds;
      final secondResult = sut.getFilenameToDebugIdMap();

      expect(firstResult, isNotNull);
      expect(firstResult, cachedResult);
      expect(secondResult, cachedResult);
    });

    test('sets the JS SDK name for native JS errors', () async {
      final sut = await fixture.getSut();
      sut.init({'dsn': fakeDsn});

      const expectedMessage = 'native js captureException error';
      final client = _getClient();
      if (client == null) {
        throw StateError('Sentry client is not registered');
      }

      final interceptedEvent = Completer<Map<dynamic, dynamic>>();
      void completeFailure(String message) {
        if (!interceptedEvent.isCompleted) {
          interceptedEvent.completeError(StateError(message));
        }
      }

      final JSFunction beforeSendEventCallback = ((JSAny? event, JSAny? _) {
        if (interceptedEvent.isCompleted) {
          return;
        }
        if (event == null) {
          completeFailure('beforeSendEvent callback received a null event.');
          return;
        }
        if (!event.isA<JSObject>()) {
          completeFailure(
              'beforeSendEvent callback received a non-JSObject event.');
          return;
        }

        final eventMap = (event as JSObject).dartify() as Map<dynamic, dynamic>;
        final exception = eventMap['exception'];
        if (exception is! Map) {
          completeFailure(
              "beforeSendEvent event is missing an 'exception' map.");
          return;
        }

        final values = exception['values'];
        if (values is! List || values.isEmpty) {
          completeFailure(
              "beforeSendEvent event exception map is missing a non-empty 'values' list.");
          return;
        }

        final firstValue = values.first;
        if (firstValue is! Map) {
          completeFailure(
              "beforeSendEvent event exception values first item is not a map.");
          return;
        }

        final value = firstValue['value'];
        if (value == null) {
          completeFailure(
              "beforeSendEvent event is missing exception 'value'.");
          return;
        }

        if (!value.toString().contains(expectedMessage)) {
          completeFailure(
            "beforeSendEvent exception value does not contain '$expectedMessage'. Actual: '$value'",
          );
          return;
        }

        interceptedEvent.complete(eventMap);
      }).toJS;
      client.on('beforeSendEvent'.toJS, beforeSendEventCallback);

      final sentry = _globalThis['Sentry'] as JSObject?;
      final jsError =
          _globalThis.callMethod('Error'.toJS, expectedMessage.toJS);
      sentry!.callMethod('captureException'.toJS, jsError);

      final processedEvent =
          await interceptedEvent.future.timeout(const Duration(seconds: 5));
      final sdk = processedEvent['sdk'] as Map<dynamic, dynamic>?;
      final exception = processedEvent['exception'] as Map<dynamic, dynamic>?;
      final values = exception?['values'] as List<dynamic>?;
      final firstValue = values?.first as Map<dynamic, dynamic>?;

      expect(sdk, isNotNull);
      expect(sdk!['name'], jsSdkName);
      expect(firstValue?['value'], contains(expectedMessage));
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

@JS('Sentry.getClient')
external SentryJsClient? _getClient();

@JS()
@staticInterop
class SentryJsClient {
  external factory SentryJsClient();
}

extension _SentryJsClientExtension on SentryJsClient {
  external void on(JSString event, JSFunction callback);
}
