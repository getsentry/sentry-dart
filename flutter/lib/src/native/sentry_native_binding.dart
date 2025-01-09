import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../replay/replay_config.dart';
import 'native_app_start.dart';
import 'native_frames.dart';

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

  FutureOr<void> beginNativeFrames();

  FutureOr<NativeFrames?> endNativeFrames(SentryId id);

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

  FutureOr<void> setReplayConfig(ReplayConfig config);

  FutureOr<SentryId> captureReplay(bool isCrash);
}
