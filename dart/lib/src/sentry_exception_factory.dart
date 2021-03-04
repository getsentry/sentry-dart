import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'throwable_mechanism.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  final SentryOptions _options;

  final SentryStackTraceFactory _stacktraceFactory;

  SentryExceptionFactory(this._options, this._stacktraceFactory);

  SentryException getSentryException(
    dynamic exception, {
    dynamic stackTrace,
  }) {
    var throwable = exception;
    var mechanism;
    if (exception is ThrowableMechanism) {
      throwable = exception.throwable;
      mechanism = exception.mechanism;
    }

    if (throwable is Error) {
      stackTrace ??= throwable.stackTrace;
    } else if (_options.attachStacktrace) {
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
