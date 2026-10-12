import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Keeps the issue title readable in obfuscated builds, where
/// `DioException.runtimeType` resolves to a minified name such as `Qx`.
class DioExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    if (throwable is DioException) return 'DioException';
    return null;
  }
}
