/// The quality of the attached screenshot
enum SentryScreenshotQuality {
  full,
  high,
  medium,
  low;

  int? targetResolution() {
    switch (this) {
      case SentryScreenshotQuality.full:
        return null; // Keep current scale
      case SentryScreenshotQuality.high:
        return 1920;
      case SentryScreenshotQuality.medium:
        return 1280;
      case SentryScreenshotQuality.low:
        return 854;
    }
  }
}
