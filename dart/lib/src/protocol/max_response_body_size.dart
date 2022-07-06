import 'package:meta/meta.dart';

/// Describes the size of http response bodies which should be added to an event
/// This enum might be removed at any time.
@experimental
enum MaxResponseBodySize {
  /// Response bodies are never sent
  never,

  /// Only small response bodies will be captured where the cutoff for small
  /// depends on the SDK (typically 4KB)
  small,

  /// Medium and small response will be captured (typically 10KB)
  medium,

  /// The SDK will always capture the request body for as long as Sentry can
  /// make sense of it
  always,
}

extension MaxResponseBodySizeX on MaxResponseBodySize {
  bool shouldAddBody(int contentLength) {
    if (this == MaxResponseBodySize.never) {
      return false;
    }
    if (this == MaxResponseBodySize.always) {
      return true;
    }
    if (this == MaxResponseBodySize.medium && contentLength <= 10000) {
      return true;
    }

    if (this == MaxResponseBodySize.small && contentLength <= 4000) {
      return true;
    }
    return false;
  }
}
