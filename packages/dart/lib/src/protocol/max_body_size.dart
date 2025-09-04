// See https://docs.sentry.io/platforms/dotnet/guides/aspnetcore/configuration/options/#max-request-body-size

import 'package:meta/meta.dart';

const _mediumSize = 10000;
const _smallSize = 4000;

/// Describes the size of http request bodies which should be added to an event
enum MaxRequestBodySize {
  /// Request bodies are never sent
  never,

  /// Only small request bodies will be captured where the cutoff for small
  /// depends on the SDK (typically 4KB)
  small,

  /// Medium and small requests will be captured (typically 10KB)
  medium,

  /// The SDK will always capture the request body for as long as Sentry can
  /// make sense of it
  always,
}

extension MaxRequestBodySizeX on MaxRequestBodySize {
  /// Returns the size limit in bytes for this setting, or null if no limit.
  @internal
  int? getSizeLimit() {
    switch (this) {
      case MaxRequestBodySize.never:
        return 0;
      case MaxRequestBodySize.small:
        return _smallSize;
      case MaxRequestBodySize.medium:
        return _mediumSize;
      case MaxRequestBodySize.always:
        return null; // No limit
    }
  }

  bool shouldAddBody(int contentLength) {
    if (this == MaxRequestBodySize.never) {
      return false; // Never add body regardless of size
    }
    final limit = getSizeLimit();
    if (limit == null) {
      return true; // No limit means always allow
    }
    return contentLength <= limit;
  }
}

/// Describes the size of http response bodies which should be added to an event
/// This enum might be removed at any time.
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
  /// Returns the size limit in bytes for this setting, or null if no limit.
  @internal
  int? getSizeLimit() {
    switch (this) {
      case MaxResponseBodySize.never:
        return 0;
      case MaxResponseBodySize.small:
        return _smallSize;
      case MaxResponseBodySize.medium:
        return _mediumSize;
      case MaxResponseBodySize.always:
        return null; // No limit
    }
  }

  bool shouldAddBody(int contentLength) {
    if (this == MaxResponseBodySize.never) {
      return false; // Never add body regardless of size
    }
    final limit = getSizeLimit();
    if (limit == null) {
      return true; // No limit means always allow
    }
    return contentLength <= limit;
  }
}
