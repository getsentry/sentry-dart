/// Describes a runtime in more detail.
///
/// Typically this context is used multiple times if multiple runtimes
/// are involved (for instance if you have a JavaScript application running
/// on top of JVM).
class Runtime {
  static const type = 'runtime';

  const Runtime({this.key, this.name, this.version, this.rawDescription})
      : assert(key == null || key.length >= 1);

  /// Key used in the JSON and which will be displayed
  /// in the Sentry UI. Defaults to lower case version of [name].
  ///
  /// Unused if only one [Runtime] is provided in [Contexts].
  final String key;

  /// The name of the runtime.
  final String name;

  /// The version identifier of the runtime.
  final String version;

  /// An unprocessed description string obtained by the runtime.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name
  /// and version from this string, if they are not explicitly given.
  final String rawDescription;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (name != null) {
      json['name'] = name;
    }

    if (version != null) {
      json['version'] = version;
    }

    if (rawDescription != null) {
      json['raw_description'] = rawDescription;
    }

    return json;
  }

  Runtime clone() => Runtime(
        key: key,
        name: name,
        version: version,
        rawDescription: rawDescription,
      );
}
