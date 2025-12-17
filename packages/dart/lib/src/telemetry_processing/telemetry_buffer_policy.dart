final class TelemetryBufferPolicy {
  final Duration flushTimeout;
  final int maxBufferSizeBytes;
  final int maxItemCount;

  const TelemetryBufferPolicy({
    this.flushTimeout = defaultFlushTimeout,
    this.maxBufferSizeBytes = defaultMaxBufferSizeBytes,
    this.maxItemCount = defaultMaxItemCount,
  });

  static const Duration defaultFlushTimeout = Duration(seconds: 5);
  static const int defaultMaxBufferSizeBytes = 1024 * 1024;
  static const int defaultMaxItemCount = 100;
}
