import 'dart:ffi';

import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'sentry_native_wrapper.dart';

/// [SentryNativeState] holds state that relates to the native SDKs. Always use
/// the shared instance with [SentryNativeState.instance].
@internal
class SentryNativeState {
  SentryNativeState();

  static SentryNativeState get instance => SentryNativeState();

  // AppStart

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;

  /// Flag used to only send app start measurement once.
  bool didFetchAppStart = false;

  // NativeFrames

  final _nativeFramesByTraceId = <SentryId, NativeFrames>{};

  void addNativeFrames(SentryId traceId, NativeFrames nativeFrames) {
    _nativeFramesByTraceId[traceId] = nativeFrames;
  }

  NativeFrames? removeNativeFrames(SentryId traceId) {
    return _nativeFramesByTraceId.remove(traceId);
  }
}
