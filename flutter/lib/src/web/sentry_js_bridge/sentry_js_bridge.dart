export 'legacy_sentry_js_bridge.dart'
    if (dart.library.js_interop) 'web_sentry_js_bridge.dart';

abstract class SentryJsBridge {
  void init(Map<String, dynamic> options);
}

// @internal
// @JS('Sentry')
// @staticInterop
// class SentryJsBridge {
//   external static void init(JSAny? options);
//
//   external static JSAny? replayIntegration(JSAny? configuration);
//
//   external static JSAny? replayCanvasIntegration();
//
//   external static void close();
//
//   external static SentryJsClient getClient();
//
//   external static void captureSession();
//
//   external static JSAny? browserTracingIntegration();
//
//   external static JSAny? breadcrumbsIntegration();
//
//   external static SentryJsScope? getCurrentScope();
//
//   external static SentryJsScope? getIsolationScope();
//
//   static SentryJsSession? getSession() {
//     return getCurrentScope()?.getSession() ?? getIsolationScope()?.getSession();
//   }
// }
//
// @JS('Replay')
// @staticInterop
// class SentryJsReplay {}
//
// extension SentryReplayExtension on SentryJsReplay {
//   external void start();
//
//   external void stop();
//
//   external JSPromise flush();
//
//   external JSString? getReplayId();
// }
//
// @JS('Session')
// @staticInterop
// class SentryJsSession {}
//
// extension SentryJsSessionExtension on SentryJsSession {
//   external JSString status;
//
//   external JSNumber errors;
// }
//
// @JS('Scope')
// @staticInterop
// class SentryJsScope {}
//
// extension SentryScopeExtension on SentryJsScope {
//   external SentryJsSession? getSession();
// }
//
// @JS('Client')
// @staticInterop
// class SentryJsClient {}
//
// extension SentryJsClientExtension on SentryJsClient {
//   external JSAny? sendEnvelope(JSAny? envelope);
// }
