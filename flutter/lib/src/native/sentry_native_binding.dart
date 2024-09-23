import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'native_app_start.dart';
import 'native_frames.dart';

/// Provide typed methods to access native layer.
@internal
abstract class SentryNativeBinding {
  Future<void> init(Hub hub);

  Future<void> close();

  Future<NativeAppStart?> fetchNativeAppStart();

  Future<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException);

  Future<void> beginNativeFrames();

  Future<NativeFrames?> endNativeFrames(SentryId id);

  Future<void> setUser(SentryUser? user);

  Future<void> addBreadcrumb(Breadcrumb breadcrumb);

  Future<void> clearBreadcrumbs();

  Future<Map<String, dynamic>?> loadContexts();

  Future<void> setContexts(String key, dynamic value);

  Future<void> removeContexts(String key);

  Future<void> setExtra(String key, dynamic value);

  Future<void> removeExtra(String key);

  Future<void> setTag(String key, String value);

  Future<void> removeTag(String key);

  int? startProfiler(SentryId traceId);

  Future<void> discardProfiler(SentryId traceId);

  Future<int?> displayRefreshRate();

  Future<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs);

  Future<List<DebugImage>?> loadDebugImages();

  Future<void> pauseAppHangTracking();

  Future<void> resumeAppHangTracking();

  Future<void> nativeCrash();

  Future<SentryId> captureReplay(bool isCrash);
}
