import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

/// [SentryNativeState] holds state that relates to the native SDKs. Always use
/// the shared instance with [SentryNativeState].
@internal
class SentryNativeState {
  SentryNativeState._();

  static final SentryNativeState _instance = SentryNativeState._();

  factory SentryNativeState() {
    return _instance;
  }

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;
}
