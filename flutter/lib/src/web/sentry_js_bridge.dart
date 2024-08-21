import 'dart:js_interop';
import 'package:meta/meta.dart';

import '../sentry_replay_options.dart';

@internal
@JS('Spotlight')
@staticInterop
class SpotlightBridge {
  external static void init();
}

@internal
@JS('Sentry')
@staticInterop
class SentryJsBridge {
  external static void init(JSAny? options);

  external static void close();

  external static JSAny? captureMessage(JSString message);

  external static JSString captureEvent(JSAny? event);

  external static JSAny? replayIntegration(JSAny? configuration);

  external static JSAny? replayCanvasIntegration();

  external static _SentryJsClient getClient();

  external static JSAny? getReplay();

  external static void captureSession();

  external static _Scope? getCurrentScope();

  external static _Scope? getIsolationScope();

  static SentryJsSession? getSession() {
    return getCurrentScope()?.getSession() ?? getIsolationScope()?.getSession();
  }
}

@JS('Session')
@staticInterop
class SentryJsSession {}

extension SentryJsSessionExtension on SentryJsSession {
  external JSString status;

  external JSNumber errors;
}

@JS('Scope')
@staticInterop
class _Scope {}

extension SentryScopeExtension on _Scope {
  external SentryJsSession? getSession();
}

extension SentryReplayExtension on JSAny? {
  external void start();

  external void startBuffering();

  external void stop();

  external void flush();

  external JSString? getReplayId();
}

@JS('Client')
@staticInterop
class _SentryJsClient {}

extension SentryJsClientExtension on _SentryJsClient {
  external JSAny? sendEnvelope(JSAny? envelope);
}
