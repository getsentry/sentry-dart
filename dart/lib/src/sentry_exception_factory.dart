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
    if (exception is ThrowableMechanism) {
      throwable = exception.throwable;
      mechanism = exception.mechanism;
    }

    if (throwable is Error) {
      stackTrace ??= throwable.stackTrace;
    }
    // throwable.stackTrace is null if its an exception that was never thrown
    // hence we check again if stackTrace is null and if not, read the current stack trace
    // but only if attachStacktrace is enabled
    if (_options.attachStacktrace) {
      stackTrace ??= StackTrace.current;
    }

    SentryStackTrace? sentryStackTrace;
    if (stackTrace != null) {
      final frames = _stacktraceFactory.getStackFrames(stackTrace);

      if (frames.isNotEmpty) {
        sentryStackTrace = SentryStackTrace(
          frames: frames,
        );
      }
    }

    // if --obfuscate feature is enabled, 'type' won't be human readable.
    // https://flutter.dev/docs/deployment/obfuscate#caveat
    final sentryException = SentryException(
      type: '${throwable.runtimeType}',
      value: '$throwable',
      mechanism: mechanism,
      stackTrace: sentryStackTrace,
    );

    return sentryException;
  }
}
