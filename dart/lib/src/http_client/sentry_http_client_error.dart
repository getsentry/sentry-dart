class SentryHttpClientError implements Exception {
  final String _message;
  SentryHttpClientError(this._message);

  @override
  String toString() => 'Exception: $_message';
}
