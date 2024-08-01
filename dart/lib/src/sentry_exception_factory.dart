import 'protocol.dart';
import 'recursive_exception_cause_extractor.dart';
import 'sentry_options.dart';
import 'sentry_stack_trace_factory.dart';
import 'throwable_mechanism.dart';
import 'utils/stacktrace_utils.dart';

/// class to convert Dart Error and exception to SentryException
class SentryExceptionFactory {
  final SentryOptions _options;

  SentryStackTraceFactory get _stacktraceFactory => _options.stackTraceFactory;

  late final extractor = RecursiveExceptionCauseExtractor(_options);

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
    stackTrace ??= _options
        .exceptionStackTraceExtractor(throwable.runtimeType)
        ?.stackTrace(throwable);

    // throwable.stackTrace is null if its an exception that was never thrown
    // hence we check again if stackTrace is null and if not, read the current stack trace
    // but only if attachStacktrace is enabled
    if (_options.attachStacktrace) {
      if (stackTrace == null || stackTrace == StackTrace.empty) {
        snapshot = true;
        stackTrace = getCurrentStackTrace();
      }
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

    final throwableString = throwable.toString();
    final stackTraceString = stackTrace.toString();
    final value = throwableString.replaceAll(stackTraceString, '').trim();

    String errorTypeName = throwable.runtimeType.toString();

    if (_options.enableExceptionTypeIdentification) {
      for (final errorTypeIdentifier in _options.exceptionTypeIdentifiers) {
        final identifiedErrorType = errorTypeIdentifier.identifyType(throwable);
        if (identifiedErrorType != null) {
          errorTypeName = identifiedErrorType;
          break;
        }
      }
    }

    // if --obfuscate feature is enabled, 'type' won't be human readable.
    // https://flutter.dev/docs/deployment/obfuscate#caveat
    return SentryException(
      type: errorTypeName,
      value: value.isNotEmpty ? value : null,
      mechanism: mechanism,
      stackTrace: sentryStackTrace,
      throwable: throwable,
    );
  }
}
