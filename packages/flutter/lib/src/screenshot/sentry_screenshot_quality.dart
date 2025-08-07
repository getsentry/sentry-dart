/// The quality of the attached screenshot
enum SentryScreenshotQuality {
  full,
  high,
  medium,
  low;

  double? targetResolution() {
    switch (this) {
      case SentryScreenshotQuality.full:
        return null; // Uses the device pixel ratio to scale the screenshot
      case SentryScreenshotQuality.high:
        return 1920;
      case SentryScreenshotQuality.medium:
        return 1280;
      case SentryScreenshotQuality.low:
        return 854;
    }
  }
}
