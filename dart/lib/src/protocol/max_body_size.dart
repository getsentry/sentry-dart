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
  bool shouldAddBody(int contentLength) {
    if (this == MaxRequestBodySize.never) {
      return false;
    }
    if (this == MaxRequestBodySize.always) {
      return true;
    }
    if (this == MaxRequestBodySize.medium && contentLength <= _mediumSize) {
      return true;
    }

    if (this == MaxRequestBodySize.small && contentLength <= _smallSize) {
      return true;
    }
    return false;
  }
}

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
    if (this == MaxResponseBodySize.medium && contentLength <= _mediumSize) {
      return true;
    }

    if (this == MaxResponseBodySize.small && contentLength <= _smallSize) {
      return true;
    }
    return false;
  }
}
