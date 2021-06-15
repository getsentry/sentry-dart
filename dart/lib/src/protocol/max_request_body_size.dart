// See https://docs.sentry.io/platforms/dotnet/guides/aspnetcore/configuration/options/#max-request-body-size
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
