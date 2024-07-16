/// An abstract class for identifying the type of Dart errors and exceptions.
///
/// This class provides a contract for implementing error type identification
/// in Dart. It's used in scenarios where error types need to be
/// determined in obfuscated builds, as [runtimeType] is not reliable in
/// such cases.
///
/// Implement this class to create custom error type identifiers for errors or exceptions.
/// that we do not support out of the box.
///
/// Add the implementation using [SentryOptions.addExceptionTypeIdentifier].
///
/// Example:
/// ```dart
/// class MyErrorTypeIdentifier implements ErrorTypeIdentifier {
///   @override
///   String? identifyType(dynamic error) {
///     if (error is MyCustomError) return 'MyCustomError';
///     return null;
///   }
/// }
/// ```
abstract class ExceptionTypeIdentifier {
  String? identifyType(dynamic throwable);
}
