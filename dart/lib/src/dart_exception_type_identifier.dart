import '../sentry.dart';

class DartExceptionTypeIdentifier implements ExceptionTypeIdentifier {
  @override
  String? identifyType(dynamic error) {
    if (error is ArgumentError) return 'ArgumentError';
    if (error is AssertionError) return 'AssertionError';
    if (error is ConcurrentModificationError)
      return 'ConcurrentModificationError';
    if (error is FormatException) return 'FormatException';
    if (error is IndexError) return 'IndexError';
    if (error is NoSuchMethodError) return 'NoSuchMethodError';
    if (error is OutOfMemoryError) return 'OutOfMemoryError';
    if (error is RangeError) return 'RangeError';
    if (error is StackOverflowError) return 'StackOverflowError';
    if (error is StateError) return 'StateError';
    if (error is TypeError) return 'TypeError';
    if (error is UnimplementedError) return 'UnimplementedError';
    if (error is UnsupportedError) return 'UnsupportedError';
    // we purposefully don't include Exception or Error since it's too generic
    return null;
  }
}
