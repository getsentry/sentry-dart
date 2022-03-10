import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'sentry_native_wrapper.dart';

/// [SentryNative] holds state that it fetches from to the native SDKs. Always
/// use the shared instance with [SentryNative()].
@internal
class SentryNative {
  SentryNative._();

  static final SentryNative _instance = SentryNative._();

  factory SentryNative() {
    return _instance;
  }

  SentryNativeWrapper? _nativeWrapper;

  /// Inject [SentryNativeWrapper] fot native layer communication.
  void injectNativeWrapper(SentryNativeWrapper nativeWrapper) {
    _nativeWrapper = nativeWrapper;
  }

  // AppStart

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;

  /// Flag used to only send app start measurement once.
  bool didFetchAppStart = false;

  // NativeFrames

  final _nativeFramesByTraceId = <SentryId, NativeFrames>{};

  Future<void> beginNativeFramesCollection(SentryId traceId) async {
    await _nativeWrapper?.beginNativeFrames();
  }

  Future<void> endNativeFramesCollection(SentryId traceId) async {
    final nativeFrames = await _nativeWrapper?.endNativeFrames(traceId);
    if (nativeFrames != null) {
      _nativeFramesByTraceId[traceId] = nativeFrames;
    }
  }

  /// Returns and removes native frames by trace id.
  NativeFrames? removeNativeFrames(SentryId traceId) {
    return _nativeFramesByTraceId.remove(traceId);
  }
}
