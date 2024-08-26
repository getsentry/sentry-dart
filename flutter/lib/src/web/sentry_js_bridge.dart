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
  void init(JSAny? options) => _SentryJsBridge.init(options);

  @override
  void close() => _SentryJsBridge.close();

  @override
  SentryJsClient getClient() => _SentryJsBridge.getClient();

  @override
  SentryJsReplay replayIntegration(JSAny? configuration) =>
      _SentryJsBridge.replayIntegration(configuration);

  @override
  JSAny? replayCanvasIntegration() => _SentryJsBridge.replayCanvasIntegration();

  @override
  JSAny? browserTracingIntegration() =>
      _SentryJsBridge.browserTracingIntegration();

  @override
  SentryJsSession? getSession() => _SentryJsBridge.getSession();

  @override
  void captureSession() => _SentryJsBridge.captureSession();

  @override
  JSAny? breadcrumbsIntegration() => _SentryJsBridge.breadcrumbsIntegration();
}

@internal
@JS('Sentry')
@staticInterop
class _SentryJsBridge {
  external static void init(JSAny? options);

  external static JSAny? replayIntegration(JSAny? configuration);

  external static JSAny? replayCanvasIntegration();

  external static void close();

  external static SentryJsClient getClient();

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
