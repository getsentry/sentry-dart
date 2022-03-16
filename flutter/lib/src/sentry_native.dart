import 'package:meta/meta.dart';

import '../sentry_flutter.dart';
import 'sentry_native_channel.dart';

/// [SentryNative] holds state that it fetches from to the native SDKs. Always
/// use the shared instance with [SentryNative()].
@internal
class SentryNative {
  SentryNative._();

  static final SentryNative _instance = SentryNative._();

  SentryNativeChannel? _nativeChannel;

  factory SentryNative() {
    return _instance;
  }

  /// Provide [nativeChannel] for native communication.
  void setNativeChannel(SentryNativeChannel nativeChannel) {
    _instance._nativeChannel = nativeChannel;
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

  Future<void> beginNativeFramesCollection(SentryId traceId) async {
    await _nativeChannel?.beginNativeFrames();
  }

  Future<NativeFrames?> endNativeFramesCollection(SentryId traceId) async {
    return await _nativeChannel?.endNativeFrames(traceId);
  }
}
