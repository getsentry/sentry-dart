import '../sentry.dart';
import 'exception_cause.dart';

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

      final extractor =
          _options.exceptionCauseExtractor(currentException.runtimeType);
      currentExceptionCause = extractor?.cause(currentException);
      currentException = currentExceptionCause?.exception;
    }
    return allExceptionCauses;
  }
}
