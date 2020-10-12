/// The Message Interface carries a log message that describes an event or error.
/// Optionally, it can carry a format string and structured parameters. This can help to group similar messages into the same issue.
/// example of a serialized message : {
///   "message": {
///     "message": "My raw message with interpreted strings like %s",
///     "params": ["this"]
///   }
/// }
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
}
