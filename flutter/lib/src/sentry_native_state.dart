import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

/// [SentryNativeState] holds state that relates to the native SDKs. Always use
/// the shared instance with [SentryNativeState.instance].
@internal
class SentryNativeState {
  SentryNativeState._();

  static final SentryNativeState _instance = SentryNativeState._();

  static SentryNativeState get instance => _instance;

  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;
}
