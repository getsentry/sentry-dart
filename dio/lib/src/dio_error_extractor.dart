import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Extracts the inner exception and stacktrace from [DioError]
class DioErrorExtractor extends ExceptionCauseExtractor<DioError> {
  @override
  ExceptionCause? cause(DioError error) {
    final cause = error.error;
    if (cause == null) {
      return null;
    }
    return ExceptionCause(
      cause,
      (cause is Error) ? cause.stackTrace : null,
    );
  }
}
