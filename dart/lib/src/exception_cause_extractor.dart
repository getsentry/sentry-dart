import 'exception_cause.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

abstract class ExceptionCauseExtractor<T> {
  ExceptionCause? cause(T error);
  Type get exceptionType => T;
}

class RecursiveExceptionCauseExtractor {
  RecursiveExceptionCauseExtractor(this._options);

  final SentryOptions _options;

  List<ExceptionCause> flatten(exception, stackTrace) {
    final allExceptionCauses = <ExceptionCause>[];
    final circularityDetector = <dynamic>{};

    var currentException = exception;
    ExceptionCause? currentExceptionCause =
        ExceptionCause(exception, stackTrace);

    while (currentException != null &&
        currentExceptionCause != null &&
        circularityDetector.add(currentException)) {
      allExceptionCauses.add(currentExceptionCause);

      final extractionSourceSource = currentException is ThrowableMechanism
          ? currentException.throwable
          : currentException;

      final extractor =
          _options.exceptionCauseExtractor(extractionSourceSource.runtimeType);

      currentExceptionCause = extractor?.cause(extractionSourceSource);
      currentException = currentExceptionCause?.exception;
    }
    return allExceptionCauses;
  }
}
