import 'package:meta/meta.dart';

import '../constants.dart';
import 'access_aware_map.dart';
import 'sentry_attribute.dart';

/// Describes a runtime in more detail.
///
/// Typically this context is used multiple times if multiple runtimes
/// are involved (for instance if you have a JavaScript application running
/// on top of JVM).
class SentryRuntime {
  static const listType = 'runtimes';
  static const type = 'runtime';

  SentryRuntime({
    this.key,
    this.name,
    this.version,
    this.compiler,
    this.rawDescription,
    this.build,
    this.unknown,
  }) : assert(key == null || key.isNotEmpty);

  /// Key used in the JSON and which will be displayed
  /// in the Sentry UI. Defaults to lower case version of [name].
  ///
  /// Unused if only one [SentryRuntime] is provided in [Contexts].
  String? key;

  /// The name of the runtime.
  String? name;

  /// The version identifier of the runtime.
  String? version;

  /// Dart has a couple different compilers.
  /// E.g: dart2js, dartdevc, AOT, VM
  String? compiler;

  /// An unprocessed description string obtained by the runtime.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name
  /// and version from this string, if they are not explicitly given.
  String? rawDescription;

  /// Application build string, if it is separate from the version.
  String? build;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryRuntime] from JSON [Map].
  factory SentryRuntime.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryRuntime(
      name: json['name'],
      version: json['version'],
      compiler: json['compiler'],
      rawDescription: json['raw_description'],
      build: json['build'],
      unknown: json.notAccessed(),
    );
  }

  /// A map of stable semantic span attributes derived from this runtime.
  ///
  /// Emits the OpenTelemetry `process.runtime.*` keys defined in
  /// [SemanticAttributesConstants]. Intended for span v2 attributes; event
  /// payloads continue to use [toJson].
  @internal
  Map<String, SentryAttribute> toAttributes() {
    final attributes = <String, SentryAttribute>{};
    final name = this.name;
    if (name != null) {
      attributes[SemanticAttributesConstants.processRuntimeName] =
          SentryAttribute.string(name);
    }
    final version = this.version;
    if (version != null) {
      attributes[SemanticAttributesConstants.processRuntimeVersion] =
          SentryAttribute.string(version);
    }
    final rawDescription = this.rawDescription;
    if (rawDescription != null) {
      attributes[SemanticAttributesConstants.processRuntimeDescription] =
          SentryAttribute.string(rawDescription);
    }
    return attributes;
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (name != null) 'name': name,
      if (compiler != null) 'compiler': compiler,
      if (version != null) 'version': version,
      if (rawDescription != null) 'raw_description': rawDescription,
      if (build != null) 'build': build,
    };
  }

  @Deprecated('Will be removed in a future version.')
  SentryRuntime clone() => SentryRuntime(
        key: key,
        name: name,
        version: version,
        compiler: compiler,
        rawDescription: rawDescription,
        build: build,
        unknown: unknown,
      );

  SentryRuntime copyWith({
    String? key,
    String? name,
    String? version,
    String? compiler,
    String? rawDescription,
    String? build,
  }) =>
      SentryRuntime(
        key: key ?? this.key,
        name: name ?? this.name,
        version: version ?? this.version,
        compiler: compiler ?? this.compiler,
        rawDescription: rawDescription ?? this.rawDescription,
        build: build ?? this.build,
        unknown: unknown,
      );
}
