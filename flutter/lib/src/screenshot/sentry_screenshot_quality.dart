import 'dart:ui';

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
        return null; // Use device resolution
      case SentryScreenshotQuality.high:
        return 1920;
      case SentryScreenshotQuality.medium:
        return 1280;
      case SentryScreenshotQuality.low:
        return 854;
    }
  }

  @internal
  int calculateHeight(int deviceWidth, int deviceHeight) {
    if (this == SentryScreenshotQuality.full) {
      // ignore: deprecated_member_use
      return window.physicalSize.height.round();
    } else {
      if (deviceHeight > deviceWidth) {
        return targetResolution()!;
      } else {
        var ratio = targetResolution()! / deviceWidth;
        return (deviceHeight * ratio).round();
      }
    }
  }

  @internal
  int calculateWidth(int deviceWidth, int deviceHeight) {
    if (this == SentryScreenshotQuality.full) {
      // ignore: deprecated_member_use
      return window.physicalSize.width.round();
    } else {
      if (deviceWidth > deviceHeight) {
        return targetResolution()!;
      } else {
        var ratio = targetResolution()! / deviceHeight;
        return (deviceWidth * ratio).round();
      }
    }
  }
}
