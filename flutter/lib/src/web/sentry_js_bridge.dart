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
}

@JS('Replay')
@staticInterop
class _SentryReplay {}

extension SentryReplayExtension on JSAny? {
  external void start();

  external void startBuffering();

  external void stop();

  external void flush();

  external JSString getReplayId();
}

@JS('Client')
@staticInterop
class _SentryJsClient {}

extension SentryJsClientExtension on _SentryJsClient {
  external JSAny? sendEnvelope(JSAny? envelope);
}
