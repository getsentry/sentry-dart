import 'package:http/http.dart' show ClientException;
import 'dart:async' show TimeoutException, AsyncError, DeferredLoadException;
import '../sentry.dart';

import 'dart_exception_type_identifier_io.dart'
    if (dart.library.html) 'dart_exception_type_identifier_web.dart';

class DartExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic throwable) {
    // dart:core
    if (throwable is ArgumentError) return 'ArgumentError';
    if (throwable is AssertionError) return 'AssertionError';
    if (throwable is ConcurrentModificationError) {
      return 'ConcurrentModificationError';
    }
    if (throwable is FormatException) return 'FormatException';
    if (throwable is IndexError) return 'IndexError';
    if (throwable is NoSuchMethodError) return 'NoSuchMethodError';
    if (throwable is OutOfMemoryError) return 'OutOfMemoryError';
    if (throwable is RangeError) return 'RangeError';
    if (throwable is StackOverflowError) return 'StackOverflowError';
    if (throwable is StateError) return 'StateError';
    if (throwable is TypeError) return 'TypeError';
    if (throwable is UnimplementedError) return 'UnimplementedError';
    if (throwable is UnsupportedError) return 'UnsupportedError';
    // not adding Exception or Error because it's too generic

    // dart:async
    if (throwable is TimeoutException) return 'TimeoutException';
    if (throwable is AsyncError) return 'FutureTimeout';
    if (throwable is DeferredLoadException) return 'DeferredLoadException';
    // not adding ParallelWaitError because it's not supported in dart 2.17.0

    // dart http package
    if (throwable is ClientException) return 'ClientException';

    // platform specific exceptions
    return identifyPlatformSpecificException(throwable);
  }
}
