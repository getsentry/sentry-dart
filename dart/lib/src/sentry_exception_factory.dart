import 'package:meta/meta.dart';

import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'throwable_mechanism.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  SentryStackTraceFactory _stacktraceFactory;
  SentryOptions _options;

  SentryExceptionFactory({
    SentryStackTraceFactory stacktraceFactory,
    @required SentryOptions options,
  }) {
    if (options == null) {
      throw ArgumentError('SentryOptions is required.');
    }

    _options = options;
    _stacktraceFactory = stacktraceFactory ?? SentryStackTraceFactory(options);
  }

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
    } else {
      stackTrace ??= StackTrace.current;
    }

    final sentryStackTrace = SentryStackTrace(
      frames: _stacktraceFactory.getStackFrames(stackTrace),
    );

    final sentryException = SentryException(
      type: '${throwable.runtimeType}',
      value: '$throwable',
      mechanism: mechanism,
      stacktrace: sentryStackTrace,
    );

    return sentryException;
  }
}
