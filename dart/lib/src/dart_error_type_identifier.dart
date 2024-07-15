import '../sentry.dart';

class DartErrorIdentifier implements ErrorTypeIdentifier {
  @override
  String? getTypeName(dynamic error) {
    if (error is NoSuchMethodError) return 'NoSuchMethodError';
    if (error is FormatException) return 'FormatException';
    if (error is TypeError) return 'TypeError';
    if (error is ArgumentError) return 'ArgumentError';
    if (error is StateError) return 'StateError';
    if (error is UnsupportedError) return 'UnsupportedError';
    if (error is UnimplementedError) return 'UnimplementedError';
    if (error is ConcurrentModificationError)
      return 'ConcurrentModificationError';
    if (error is OutOfMemoryError) return 'OutOfMemoryError';
    if (error is StackOverflowError) return 'StackOverflowError';
    return null;
  }
}
