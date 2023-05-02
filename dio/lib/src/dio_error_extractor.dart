import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';
import 'dart:collection';

/// Extracts the inner cause and stacktrace from [DioError]
class DioErrorExtractor extends ExceptionCauseExtractor<DioError> {
  @override
  ExceptionCause?
  cause(DioError error) {
    final cause = error.error;
    if (cause == null) {
      return null;
    }
    return ExceptionCause(
      cause,
      // A custom [ExceptionStackTraceExtractor] can be
      // used to extract the inner stacktrace in other cases
      cause is Error ? cause.stackTrace : null,
    );
  }
}
