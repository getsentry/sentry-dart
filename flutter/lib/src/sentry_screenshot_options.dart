import 'dart:async';

import '../sentry_flutter.dart';

/// Configuration of the screenshot feature.
class SentryScreenshotOptions {
  /// Automatically attaches a screenshot when capturing an error or exception.
  ///
  /// Requires adding the [SentryWidget] to the widget tree.
  /// Example:
  /// runApp(SentryWidget(child: App()));
  /// The [SentryWidget] has to be the root widget of the app.
  bool attach = false;

  /// Sets a callback which is executed before capturing screenshots. Only
  /// relevant if `attach` is set to true. When false is returned
  /// from the function, no screenshot will be attached.
  BeforeScreenshotCallback? beforeCapture;

  /// Only attach a screenshot when the app is resumed.
  /// See https://docs.sentry.io/platforms/flutter/troubleshooting/#screenshot-integration-background-crash
  bool attachOnlyWhenResumed = false;

  /// The quality of the attached screenshot
  SentryScreenshotQuality quality = SentryScreenshotQuality.high;
}

/// Callback being executed in [ScreenshotEventProcessor], deciding if a
/// screenshot should be recorded and attached.
typedef BeforeScreenshotCallback = FutureOr<bool> Function(
  SentryEvent event, {
  Hint? hint,
});
