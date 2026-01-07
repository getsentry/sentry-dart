/// Controls how trace data is collected and transmitted to Sentry.
enum SentryTraceLifecycle {
  /// Spans are sent individually as they complete.
  ///
  /// Each span is buffered and transmitted independently without waiting for the entire trace to finish.
  streaming,

  /// Spans are buffered and sent as a complete transaction.
  ///
  /// All spans in a trace are collected and transmitted together when the
  /// root span ends, matching the traditional transaction model.
  static,
}
