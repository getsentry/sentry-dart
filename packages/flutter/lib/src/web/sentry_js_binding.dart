import 'package:flutter/cupertino.dart';

export 'noop_sentry_js_binding.dart'
    if (dart.library.js_interop) 'web_sentry_js_binding.dart';

abstract class SentryJsBinding {
  void init(Map<String, dynamic> options);
  void close();

  /// Sends [envelope] through the JS SDK's transport. [events] are the
  /// events and transactions in it, as JSON; once sent, they're reported to
  /// the JS SDK's `afterSendEvent` hook, as its own `sendEvent()` does.
  void captureEnvelope(
    List<Object> envelope,
    List<Map<String, dynamic>> events,
  );
  void setUser(Map<String, dynamic>? user);
  void addBreadcrumb(Map<String, dynamic> breadcrumb);
  void addReplayBreadcrumb(Map<String, dynamic> breadcrumb);
  void clearBreadcrumbs();
  void setContext(String key, Object? value);
  void removeContext(String key);
  void setExtra(String key, Object? value);
  void removeExtra(String key);
  void setTag(String key, String value);
  void removeTag(String key);
  void startSession();
  Map<dynamic, dynamic>? getSession();
  void updateSession({int? errors, String? status});
  void captureSession();
  Map<String, String>? getFilenameToDebugIdMap();

  /// The current JS replay's ID, or `null` without one.
  ///
  /// With [onlyIfSampled], also `null` for a replay whose session wasn't
  /// sampled. A replay buffering for `replaysOnErrorSampleRate` counts as
  /// sampled: the JS SDK only drops the ID when the session's `sampled` is
  /// `false`, and it's `'buffer'` then (`ReplayContainer.getSessionId` in
  /// @sentry-internal/replay 11.0.0).
  String? getReplayId({bool onlyIfSampled = false});
  void startReplay();
  void startReplayBuffering();
  Future<void> stopReplay();
  Future<void> flushReplay();

  /// Constructs the JS SDK's canvas-replay integration in manual-snapshot
  /// mode and returns a reference to it -- unlike other integrations, this
  /// one needs to be driven after construction (see [SentryWebReplayRecorder]
  /// and the `WebReplayCanvasBridge` it feeds), not just installed.
  ///
  /// Typed as [Object] here (rather than the real, web-only interop type)
  /// so this interface stays importable on every platform -- see the
  /// conditional export below. Returns `null` on platforms without a real
  /// JS SDK to construct it from.
  Object? createManualReplayCanvasIntegration();
  @visibleForTesting
  dynamic getJsOptions();
}

/// Names of the JS integrations that we want to add when initializing the JS SDK
class SentryJsIntegrationName {
  const SentryJsIntegrationName._();

  static const String globalHandlers = 'globalHandlersIntegration';
  static const String dedupe = 'dedupeIntegration';
  static const String httpContext = 'httpContextIntegration';
  static const String replay = 'replayIntegration';
  static const String replayCanvas = 'replayCanvasIntegration';
}
