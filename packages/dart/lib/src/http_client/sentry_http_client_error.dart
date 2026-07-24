class SentryHttpClientError implements Exception {
  final String _message;
  SentryHttpClientError(this._message);

  /// Returned unprefixed so the exception value reads exactly like the other
  /// SDKs' HTTP client errors.
  @override
  String toString() => _message;
}
