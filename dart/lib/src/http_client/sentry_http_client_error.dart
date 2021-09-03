class SentryHttpClientError extends Error {
  final String _message;
  SentryHttpClientError(this._message);

  @override
  String toString() => _message;
}
