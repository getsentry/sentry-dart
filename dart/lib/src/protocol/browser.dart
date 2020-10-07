/// Carries information about the browser or user agent for web-related errors.
///
/// This can either be the browser this event ocurred in, or the user
/// agent of a web request that triggered the event.
class Browser {
  /// Creates an instance of [Browser].
  const Browser({this.name, this.version});

  /// Human readable application name, as it appears on the platform.
  final String name;

  /// Human readable application version, as it appears on the platform.
  final String version;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (name != null) {
      json['name'] = name;
    }

    if (version != null) {
      json['version'] = version;
    }

    return json;
  }
}
