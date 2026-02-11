import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../replay/replay_config.dart';
import 'native_app_start.dart';

/// Provide typed methods to access native layer.
@internal
abstract class SentryNativeBinding {
  FutureOr<void> init(Hub hub);

  FutureOr<void> close();

  FutureOr<NativeAppStart?> fetchNativeAppStart();

  bool get supportsCaptureEnvelope;

  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException);

  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope);

  FutureOr<void> setUser(SentryUser? user);

  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb);

  FutureOr<void> clearBreadcrumbs();

  bool get supportsLoadContexts;

  FutureOr<Map<String, dynamic>?> loadContexts();

  FutureOr<void> setContexts(String key, dynamic value);

  FutureOr<void> removeContexts(String key);

  FutureOr<void> setExtra(String key, dynamic value);

  FutureOr<void> removeExtra(String key);

  FutureOr<void> setTag(String key, String value);

  FutureOr<void> removeTag(String key);

  int? startProfiler(SentryId traceId);

  FutureOr<void> discardProfiler(SentryId traceId);

  FutureOr<int?> displayRefreshRate();

  FutureOr<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs);

  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace);

  FutureOr<void> pauseAppHangTracking();

  FutureOr<void> resumeAppHangTracking();

  FutureOr<void> nativeCrash();

  bool get supportsReplay;

  SentryId? get replayId;

  FutureOr<void> setReplayConfig(ReplayConfig config);

  FutureOr<SentryId> captureReplay();

  /// Starts a new session.
  ///
  /// Note: This is used on web platforms. Android and iOS handle sessions
  /// automatically through their respective native SDKs.
  /// Windows and Linux currently don't support sessions.
  ///
  /// @param ignoreDurations If true, the session will ignore the configured session duration
  FutureOr<void> startSession({bool ignoreDuration = false});

  /// Gets the current active session.
  ///
  /// Note: This is used on web platforms and returns null on non-web.
  FutureOr<Map<dynamic, dynamic>?> getSession();

  /// Updates the current session with the provided status and/or error count.
  ///
  /// Note: This is used on web platforms and is a no-op on non-web.
  FutureOr<void> updateSession({int? errors, String? status});

  /// Sends the current session immediately.
  ///
  /// NNote: This is used on web platforms and is a no-op on non-web.
  FutureOr<void> captureSession();

  /// Whether the native SDK supports syncing the trace id.
  bool get supportsTraceSync;

  /// Sets the trace context on the native SDK scope.
  FutureOr<void> setTrace(SentryId traceId,
      {SpanId? spanId, double? sampleRate, double? sampleRand});
}
