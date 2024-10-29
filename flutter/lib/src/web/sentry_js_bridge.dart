import 'dart:js_interop';
import 'package:meta/meta.dart';

/// Low-level interface for direct JavaScript SDK operations.
///
/// Provides raw access to JS SDK functionality with JS types.
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

class SentryJsSdk implements SentryJsApi {
  @override
  void init(JSAny? options) => _SentryJs.init(options);

  @override
  void close() => _SentryJs.close();

  @override
  SentryJsClient getClient() => _SentryJs.getClient();

  @override
  SentryJsReplay replayIntegration(JSAny? configuration) =>
      _SentryJs.replayIntegration(configuration)!;

  @override
  JSAny? replayCanvasIntegration() => _SentryJs.replayCanvasIntegration();

  @override
  JSAny? browserTracingIntegration() => _SentryJs.browserTracingIntegration();

  @override
  SentryJsSession? getSession() => _SentryJs.getSession();

  @override
  void captureSession() => _SentryJs.captureSession();

  @override
  JSAny? breadcrumbsIntegration() => _SentryJs.breadcrumbsIntegration();
}

/// Raw JavaScript interop with Sentry JS Browser
@internal
@JS('Sentry')
@staticInterop
class _SentryJs {
  external static void init(JSAny? options);

  external static SentryJsReplay? replayIntegration(JSAny? configuration);

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
