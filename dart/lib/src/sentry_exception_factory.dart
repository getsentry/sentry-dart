import 'package:meta/meta.dart';

import 'protocol/sentry_stack_trace.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  SentryStackTraceFactory _stacktraceFactory;

  SentryExceptionFactory({
    SentryStackTraceFactory stacktraceFactory,
    @required SentryOptions options,
  }) {
    if (options == null) {
      throw ArgumentError('SentryOptions is required.');
    }

    _stacktraceFactory = stacktraceFactory ?? SentryStackTraceFactory(options);
  }

  SentryException getSentryException(
    dynamic exception, {
    dynamic stackTrace,
    Mechanism mechanism,
  }) {
    if (exception is Error) {
      stackTrace ??= exception.stackTrace;
    } else {
      stackTrace ??= StackTrace.current;
    }

    final sentryStackTrace = SentryStackTrace(
      frames: _stacktraceFactory.getStackFrames(stackTrace),
    );

    final sentryException = SentryException(
      type: '${exception.runtimeType}',
      value: '$exception',
      mechanism: mechanism,
      stacktrace: sentryStackTrace,
    );

    return sentryException;
  }
}
