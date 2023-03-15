/// Holds inner exception and stackTrace combinations contained in other exceptions
class ExceptionCause {
  ExceptionCause(this.exception, this.stackTrace);

  dynamic exception;
  dynamic stackTrace;
}
