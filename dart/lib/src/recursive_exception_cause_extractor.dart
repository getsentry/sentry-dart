import 'sentry_options.dart';
import 'throwable_mechanism.dart';
import 'exception_cause.dart';
import 'protocol.dart';
import 'package:meta/meta.dart';

/// Extracts inner exceptions recursively
@internal
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

      try {
        currentExceptionCause = extractor?.cause(extractionSourceSource);
        currentException = currentExceptionCause?.exception;
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'An exception occurred while extracting  exception cause',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
        break;
      }
    }
    return allExceptionCauses;
  }
}
