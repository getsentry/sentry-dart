import 'dart:js_interop';
import 'package:meta/meta.dart';

abstract class SentryJsApi {
  void init(JSAny? options);
  void close();
  SentryJsClient getClient();
  SentryJsReplay replayIntegration(JSAny? configuration);
  JSAny? replayCanvasIntegration();
  JSAny? browserTracingIntegration();
  JSAny? breadcrumbsIntegration();
  SentryJsSession? getSession();
  void captureSession();
}

class SentryJsWrapper implements SentryJsApi {
  @override
  void init(JSAny? options) => SentryJsBridge.init(options);

  @override
  void close() => SentryJsBridge.close();

  @override
  SentryJsClient getClient() => SentryJsBridge.getClient();

  @override
  SentryJsReplay replayIntegration(JSAny? configuration) =>
      SentryJsBridge.replayIntegration(configuration);

  @override
  JSAny? replayCanvasIntegration() => SentryJsBridge.replayCanvasIntegration();

  @override
  JSAny? browserTracingIntegration() =>
      SentryJsBridge.browserTracingIntegration();

  @override
  SentryJsSession? getSession() => SentryJsBridge.getSession();

  @override
  void captureSession() => SentryJsBridge.captureSession();

  @override
  JSAny? breadcrumbsIntegration() => SentryJsBridge.breadcrumbsIntegration();
}

@internal
@JS('Sentry')
@staticInterop
class SentryJsBridge {
  external static void init(JSAny? options);

  external static void close();

  external static SentryJsReplay replayIntegration(JSAny? configuration);

  external static JSAny? replayCanvasIntegration();

  external static SentryJsClient getClient();

  external static JSAny? getReplay();

  external static void captureSession();

  external static JSAny? browserTracingIntegration();

  external static JSAny? breadcrumbsIntegration();

  external static SentryJsScope? getCurrentScope();

  external static SentryJsScope? getIsolationScope();

  static SentryJsSession? getSession() {
    return getCurrentScope()?.getSession() ?? getIsolationScope()?.getSession();
  }
}

@JS('Replay')
@staticInterop
class SentryJsReplay {}

extension SentryReplayExtension on SentryJsReplay {
  external void start();

  external void stop();

  external JSPromise flush();

  external JSString? getReplayId();
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
class SentryJsScope {}

extension SentryScopeExtension on SentryJsScope {
  external SentryJsSession? getSession();
}

@JS('Client')
@staticInterop
class SentryJsClient {}

extension SentryJsClientExtension on SentryJsClient {
  external JSAny? sendEnvelope(JSAny? envelope);
}
