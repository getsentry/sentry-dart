import 'package:meta/meta.dart';

import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'throwable_mechanism.dart';

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
  }) {
    var throwable = exception;
    var mechanism;
    if (exception is ThrowableMechanism) {
      throwable = exception.throwable;
      mechanism = exception.mechanism;
    }

    if (throwable is Error) {
      stackTrace ??= throwable.stackTrace;
    } else if(_options.attachStackTrace){
      stackTrace ??= StackTrace.current;
    }

    SentryStackTrace sentryStackTrace;
    if( stackTrace != null) {
      sentryStackTrace = SentryStackTrace(
        frames: _stacktraceFactory.getStackFrames(stackTrace),
      );
    }
    final sentryException = SentryException(
      type: '${throwable.runtimeType}',
      value: '$throwable',
      mechanism: mechanism,
      stackTrace: sentryStackTrace,
    );

    return sentryException;
  }
}
