class SpanDataConvention {
  SpanDataConvention._();

  static const totalFrames = 'frames.total';
  static const slowFrames = 'frames.slow';
  static const frozenFrames = 'frames.frozen';
  static const framesDelay = 'frames.delay';

  // Thread/Isolate data keys according to Sentry span data conventions
  // https://develop.sentry.dev/sdk/telemetry/traces/span-data-conventions/#thread
  static const threadId = 'thread.id';
  static const threadName = 'thread.name';
  static const blockedMainThread = 'blocked_main_thread';

  // TODO: eventually add other data keys here as well
}
