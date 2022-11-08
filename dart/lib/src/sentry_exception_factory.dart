import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'throwable_mechanism.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  final SentryOptions _options;

  SentryStackTraceFactory get _stacktraceFactory => _options.stackTraceFactory;

  SentryExceptionFactory(this._options);

  SentryException getSentryException(
    dynamic exception, {
    dynamic stackTrace,
  }) {
    var throwable = exception;
    Mechanism? mechanism;
    bool? snapshot;
    if (exception is ThrowableMechanism) {
      throwable = exception.throwable;
      mechanism = exception.mechanism;
      snapshot = exception.snapshot;
    }

    if (throwable is Error) {
      stackTrace ??= throwable.stackTrace;
    }
    // throwable.stackTrace is null if its an exception that was never thrown
    // hence we check again if stackTrace is null and if not, read the current stack trace
    // but only if attachStacktrace is enabled
    if (_options.attachStacktrace) {
      // TODO: snapshot=true if stackTrace is null
      // Requires a major breaking change because of grouping
      stackTrace ??= StackTrace.current;
    }

    SentryStackTrace? sentryStackTrace;
    if (stackTrace != null) {
      final frames = _stacktraceFactory.getStackFrames(stackTrace);

      if (frames.isNotEmpty) {
        sentryStackTrace = SentryStackTrace(
          frames: frames,
          snapshot: snapshot,
        );
      }
    }

    // if --obfuscate feature is enabled, 'type' won't be human readable.
    // https://flutter.dev/docs/deployment/obfuscate#caveat
    return SentryException(
      type: (throwable.runtimeType).toString(),
      value: throwable.toString(),
      mechanism: mechanism,
      stackTrace: sentryStackTrace,
    );
  }
}
