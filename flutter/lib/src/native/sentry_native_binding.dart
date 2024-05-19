import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'sentry_native.dart';

/// Provide typed methods to access native layer.
@internal
abstract class SentryNativeBinding {
  // TODO Move other native calls here.
  Future<void> init(SentryFlutterOptions options);

  Future<void> close();

  Future<NativeAppStart?> fetchNativeAppStart();

  Future<void> beginNativeFrames();

  Future<NativeFrames?> endNativeFrames(SentryId id);

  Future<void> setUser(SentryUser? user);

  Future<void> addBreadcrumb(Breadcrumb breadcrumb);

  Future<void> clearBreadcrumbs();

  Future<void> setContexts(String key, dynamic value);

  Future<void> removeContexts(String key);

  Future<void> setExtra(String key, dynamic value);

  Future<void> removeExtra(String key);

  Future<void> setTag(String key, String value);

  Future<void> removeTag(String key);

  int? startProfiler(SentryId traceId);

  Future<void> discardProfiler(SentryId traceId);

  Future<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs);
}
