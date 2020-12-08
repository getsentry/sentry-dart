import 'package:meta/meta.dart';

/// Describes a runtime in more detail.
///
/// Typically this context is used multiple times if multiple runtimes
/// are involved (for instance if you have a JavaScript application running
/// on top of JVM).
@immutable
class SentryRuntime {
  static const listType = 'runtimes';
  static const type = 'runtime';

  const SentryRuntime({this.key, this.name, this.version, this.rawDescription})
      : assert(key == null || key.length >= 1);

  factory SentryRuntime.fromJson(Map<String, dynamic> data) => SentryRuntime(
        name: data['name'],
        version: data['version'],
        rawDescription: data['raw_description'],
      );

  /// Key used in the JSON and which will be displayed
  /// in the Sentry UI. Defaults to lower case version of [name].
  ///
  /// Unused if only one [SentryRuntime] is provided in [Contexts].
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

  SentryRuntime clone() => SentryRuntime(
        key: key,
        name: name,
        version: version,
        rawDescription: rawDescription,
      );

  SentryRuntime copyWith({
    String key,
    String name,
    String version,
    String rawDescription,
  }) =>
      SentryRuntime(
        key: key ?? this.key,
        name: name ?? this.name,
        version: version ?? this.version,
        rawDescription: rawDescription ?? this.rawDescription,
      );
}
