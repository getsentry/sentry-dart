class Message {
  /// The fully formatted message. If missing, Sentry will try to interpolate the message.
  final String formatted;

  /// The raw message string (uninterpolated).
  /// example : "My raw message with interpreted strings like %s",
  final String message;

  /// A list of formatting parameters, preferably strings. Non-strings will be coerced to strings.
  final List<dynamic> params;

  Message({this.formatted, this.message, this.params});

  Map<String, dynamic> toJson() {
    return {
      'formatted': formatted,
      'message': message,
      'params': params,
    };
  }

  @override
  String toString() {
    return 'Message{formatted: $formatted, message: $message, params: $params}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          formatted == other.formatted &&
          message == other.message &&
          params == other.params;

  @override
  int get hashCode => formatted.hashCode ^ message.hashCode ^ params.hashCode;
}
