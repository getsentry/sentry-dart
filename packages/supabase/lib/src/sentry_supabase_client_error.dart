class SentrySupabaseClientError implements Exception {
  final String _message;
  SentrySupabaseClientError(this._message);

  @override
  String toString() => 'Exception: $_message';
}
