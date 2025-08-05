class InvalidSentryTraceHeaderException implements Exception {
  final String _message;
  InvalidSentryTraceHeaderException(this._message);

  @override
  String toString() => 'Exception: $_message';
}
