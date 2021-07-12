import 'package:meta/meta.dart';

/// Carries information about the browser or user agent for web-related errors.
///
/// This can either be the browser this event ocurred in, or the user
/// agent of a web request that triggered the event.
@immutable
class SentryBrowser {
  static const type = 'browser';

  /// Creates an instance of [SentryBrowser].
  const SentryBrowser({this.name, this.version});

  /// Human readable application name, as it appears on the platform.
  final String? name;

  /// Human readable application version, as it appears on the platform.
  final String? version;

  /// Deserializes a [SentryBrowser] from JSON [Map].
  // ignore: strict_raw_type
  factory SentryBrowser.fromJson(Map data) => SentryBrowser(
        // This class should be deserializable from Map<String, dynamic> and Map<Object?, Object?>,
        // because it comes from json.decode which is a Map<String, dynamic> and from
        // methodchannels which is a Map<Object?, Object?>.
        // Map<String, dynamic> and Map<Object?, Object?> only have
        // Map<dynamic, dynamic> as common type constraint
        name: data['name'] as String?,
        version: data['version'] as String?,
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, Object> toJson() {
    return <String, Object>{
      if (name != null) 'name': name!,
      if (version != null) 'version': version!,
    };
  }

  SentryBrowser clone() => SentryBrowser(name: name, version: version);

  SentryBrowser copyWith({
    String? name,
    String? version,
  }) =>
      SentryBrowser(
        name: name ?? this.name,
        version: version ?? this.version,
      );
}
