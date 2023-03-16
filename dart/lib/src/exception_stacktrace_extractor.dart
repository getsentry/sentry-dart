import 'protocol.dart';
import 'sentry_options.dart';

/// Sentry handles [Error.stackTrace] by default. For other cases
/// extend this abstract class and return a custom [StackTrace] of your
/// exceptions.
///
/// Implementing an extractor and providing it through
/// [SentryOptions.addExceptionStackTraceExtractor] will enable the framework to
/// extract the inner stacktrace and add it to [SentryException] when no other
/// stacktrace was provided while capturing the event.
///
/// For an example on how to use the API refer to dio/DioStackTraceExtractor or the
/// code below:
///
/// ```dart
/// class ExceptionWithInner {
///   ExceptionWithInner(this.innerException, this.innerStackTrace);
///   Object innerException;
///   dynamic innerStackTrace;
/// }
///
/// class ExceptionWithInnerStackTraceExtractor extends ExceptionStackTraceExtractor<ExceptionWithInner>  {
///   @override
///   dynamic cause(ExceptionWithInner error) {
///     return error.innerStackTrace;
///   }
/// }
///
/// options.addExceptionStackTraceExtractor(ExceptionWithInnerStackTraceExtractor());
/// ```
abstract class ExceptionStackTraceExtractor<T> {
  dynamic stackTrace(T error);
  Type get exceptionType => T;
}
