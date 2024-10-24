import 'package:meta/meta.dart';

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

  @internal
  int calculateHeight(int width, int height) {
    if (this == SentryScreenshotQuality.full) {
      return height;
    } else {
      if (height > width) {
        return targetResolution()!;
      } else {
        var ratio = targetResolution()! / width;
        return (height * ratio).round();
      }
    }
  }

  @internal
  int calculateWidth(int width, int height) {
    if (this == SentryScreenshotQuality.full) {
      return width;
    } else {
      if (width > height) {
        return targetResolution()!;
      } else {
        var ratio = targetResolution()! / height;
        return (width * ratio).round();
      }
    }
  }
}
