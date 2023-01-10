import 'exception_cause.dart';

class ExceptionCauseExtractor<T> {
  ExceptionCause? cause(T error) {
    return null;
  }
}

class RecursiveExceptionCauseExtractor {
  RecursiveExceptionCauseExtractor(this.causeExtractorsByType);

  final Map<Type, ExceptionCauseExtractor> causeExtractorsByType;

  List<ExceptionCause> flatten(exception, stackTrace) {
    var allExceptionCauses = <ExceptionCause>[];

    var currentException = exception;
    ExceptionCause? currentExceptionCause =
        ExceptionCause(exception, stackTrace);

    while (currentException != null && currentExceptionCause != null) {
      allExceptionCauses.add(currentExceptionCause);

      final extractor = causeExtractorsByType[currentException.runtimeType];
      currentExceptionCause = extractor?.cause(currentException);
      currentException = currentExceptionCause?.exception;
    }
    return allExceptionCauses;
  }
}
