// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Extracts the inner stacktrace from [DioError]
class DioStackTraceExtractor extends ExceptionStackTraceExtractor<DioError> {
  @override
  StackTrace? stackTrace(DioError error) {
    return error.stackTrace;
  }
}
