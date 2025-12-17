import 'package:meta/meta.dart';

/// Interface for objects that can be serialized to JSON for Sentry transmission.
abstract class SentryEncodable {
  /// Converts this object to a JSON-compatible map.
  @internal
  Map<String, dynamic> toJson();
}
