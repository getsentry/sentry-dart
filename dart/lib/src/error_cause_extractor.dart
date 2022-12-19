class CauseExtractor<T> {
  Object? cause(T error) { return null; }
}

class ErrorCauseExtractor {
  ErrorCauseExtractor(this.causeExtractorsByType);

  final Map<Type, CauseExtractor> causeExtractorsByType;

  List<Object> flatten(errorWithCause) {
    var allErrors = <Object>[];
    var current = errorWithCause;

    while (current != null) {
      allErrors.add(current);
      final causeExtractor = causeExtractorsByType[current.runtimeType];
      current = causeExtractor?.cause(current);
    }
    return allErrors;
  }
}
