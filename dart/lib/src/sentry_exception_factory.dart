import 'package:meta/meta.dart';

import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  final SentryOptions _options;

  final SentryStackTraceFactory _stacktraceFactory;

  SentryExceptionFactory({
    @required SentryStackTraceFactory stacktraceFactory,
    @required SentryOptions options,
  })  : _options = options,
        _stacktraceFactory = stacktraceFactory {
    if (_options == null) {
      throw ArgumentError('SentryOptions is required.');
    }

    if (_stacktraceFactory == null) {
      throw ArgumentError('SentryStackTraceFactory is required.');
    }
  }

  SentryException getSentryException(
    dynamic exception, {
    dynamic stackTrace,
    Mechanism mechanism,
  }) {
    if (exception is Error) {
      stackTrace ??= exception.stackTrace;
    } else if (_options.attachStackTrace) {
      stackTrace ??= StackTrace.current;
    }

    SentryStackTrace sentryStackTrace;
    if (stackTrace != null) {
      sentryStackTrace = SentryStackTrace(
        frames: _stacktraceFactory.getStackFrames(stackTrace),
      );
    }

    final sentryException = SentryException(
      type: '${exception.runtimeType}',
      value: '$exception',
      mechanism: mechanism,
      stacktrace: sentryStackTrace,
    );

    return sentryException;
  }
}
