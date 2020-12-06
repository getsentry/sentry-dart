import 'package:meta/meta.dart';

import 'protocol.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'throwable_mechanism.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  final SentryOptions _options;

  final SentryStackTraceFactory _stacktraceFactory;

  SentryExceptionFactory._(this._options, this._stacktraceFactory);

  factory SentryExceptionFactory({
    @required SentryOptions options,
    @required SentryStackTraceFactory stacktraceFactory,
  }) {
    if (options == null) {
      throw ArgumentError('SentryOptions is required.');
    }

    if (stacktraceFactory == null) {
      throw ArgumentError('SentryStackTraceFactory is required.');
    }
    return SentryExceptionFactory._(options, stacktraceFactory);
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
    } else if (_options.attachStacktrace) {
      stackTrace ??= StackTrace.current;
    }

    SentryStackTrace sentryStackTrace;
    if (stackTrace != null) {
      sentryStackTrace = SentryStackTrace(
        frames: _stacktraceFactory.getStackFrames(stackTrace),
      );
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
