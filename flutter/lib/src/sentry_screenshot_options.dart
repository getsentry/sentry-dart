import 'dart:async';

import '../sentry_flutter.dart';

/// Configuration of the screenshot feature.
class SentryScreenshotOptions {
  /// Automatically attaches a screenshot when capturing an error or exception.
  ///
  /// Requires adding the [SentryScreenshotWidget] to the widget tree.
  /// Example:
  /// runApp(SentryScreenshotWidget(child: App()));
  /// The [SentryScreenshotWidget] has to be the root widget of the app.
  bool attachScreenshot = false;

  /// Sets a callback which is executed before capturing screenshots. Only
  /// relevant if `attachScreenshot` is set to true. When false is returned
  /// from the function, no screenshot will be attached.
  BeforeScreenshotCallback? beforeScreenshot;

  /// Only attach a screenshot when the app is resumed.
  bool attachScreenshotOnlyWhenResumed = false;

  /// The quality of the attached screenshot
  SentryScreenshotQuality screenshotQuality = SentryScreenshotQuality.high;
}

/// Callback being executed in [ScreenshotEventProcessor], deciding if a
/// screenshot should be recorded and attached.
typedef BeforeScreenshotCallback = FutureOr<bool> Function(
  SentryEvent event, {
  Hint? hint,
});
