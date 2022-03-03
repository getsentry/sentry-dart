import 'package:meta/meta.dart';

import '../sentry_flutter.dart';

/// [SentryNativeState] holds state that relates to the native SDKs.
@internal
class SentryNativeState {
  /// This timestamp marks the end of app startup. Either set automatically when
  /// [SentryFlutterOptions.autoAppStart] is true, or by calling
  /// [SentryFlutter.setAppStartEnd]
  DateTime? appStartEnd;
}
