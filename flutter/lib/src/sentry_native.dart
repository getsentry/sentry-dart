import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'sentry_native_wrapper.dart';

/// [SentryNative] holds state that it fetches from to the native SDKs. Always
/// use the shared instance with [SentryNative()].
@internal
class SentryNative {
  SentryNative._();

  static final SentryNative _instance = SentryNative._();

  SentryNativeChannel? _nativeChannel;

  factory SentryNative({SentryNativeChannel? nativeChannel}) {
    if (nativeChannel != null) {
      _instance._nativeChannel = nativeChannel;
    }
    return _instance;
  }

  // AppStart

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;

  bool _didFetchAppStart = false;

  /// Flag indicating if app start was already fetched.
  bool get didFetchAppStart => _didFetchAppStart;

  /// Fetch [NativeAppStart] from native channels. Can only be called once.
  Future<NativeAppStart?> fetchNativeAppStart() async {
    _didFetchAppStart = true;
    return await _nativeChannel?.fetchNativeAppStart();
  }

  // NativeFrames

  final _nativeFramesByTraceId = <SentryId, NativeFrames>{};

  Future<void> beginNativeFramesCollection(SentryId traceId) async {
    await _nativeChannel?.beginNativeFrames();
  }

  Future<void> endNativeFramesCollection(SentryId traceId) async {
    final nativeFrames = await _nativeChannel?.endNativeFrames(traceId);
    if (nativeFrames != null) {
      _nativeFramesByTraceId[traceId] = nativeFrames;
    }
  }

  /// Returns and removes native frames by trace id.
  NativeFrames? removeNativeFrames(SentryId traceId) {
    return _nativeFramesByTraceId.remove(traceId);
  }
}
