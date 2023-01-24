import 'protocol.dart';
import 'exception_cause.dart';
import 'sentry_options.dart';

/// Extend this abstract class and return inner [ExceptionCause] of your
/// exceptions.
///
/// Implementing an extractor and providing it through
/// [SentryOptions.addExceptionCauseExtractor] will enable the framework to
/// extract the inner exceptions and add them as [SentryException] to
/// [SentryEvent.exceptions].
///
/// Example:
///
/// ```dart
/// class ExceptionWithInner {
///   ExceptionWithInner(this.innerException, this.innerStackTrace);
///   Object innerException;
///   StackTrace innerStackTrace;
/// }
///
/// class ExceptionWithInnerExtractor extends ExceptionCauseExtractor<ExceptionWithInner>  {
///   @override
///   ExceptionCause? cause(ExceptionWithInner error) {
///     return ExceptionCause(error.innerException, error.innerStackTrace);
///   }
/// }
///
/// options.addExceptionCauseExtractor(ExceptionWithInnerExtractor());
/// ```
abstract class ExceptionCauseExtractor<T> {
  ExceptionCause? cause(T error);
  Type get exceptionType => T;
}
