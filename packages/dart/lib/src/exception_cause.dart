/// Holds inner exception and stackTrace combinations contained in other exceptions
class ExceptionCause {
  ExceptionCause(this.exception, this.stackTrace, {this.source});

  dynamic exception;
  dynamic stackTrace;
  String? source;
}
