import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Extracts the inner exception and stacktrace from [DioError]
class DioErrorExtractor extends ExceptionCauseExtractor<DioError> {
  @override
  ExceptionCause? cause(DioError error) {
    if (error.stackTrace == null) {
      return null;
    }
    return ExceptionCause(
      error.error ?? 'DioError inner stacktrace',
      error.stackTrace,
    );
  }
}
