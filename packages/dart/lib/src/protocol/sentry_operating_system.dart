import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// Describes the operating system on which the event was created.
///
/// In web contexts, this is the operating system of the browse
/// (normally pulled from the User-Agent string).
class SentryOperatingSystem {
  static const type = 'os';

  SentryOperatingSystem({
    this.name,
    this.version,
    this.build,
    this.kernelVersion,
    this.rooted,
    this.rawDescription,
    this.theme,
    this.unknown,
  });

  /// The name of the operating system.
  String? name;

  /// The version of the operating system.
  String? version;

  /// The internal build revision of the operating system.
  String? build;

  /// An independent kernel version string.
  ///
  /// This is typically the entire output of the `uname` syscall.
  String? kernelVersion;

  /// A flag indicating whether the OS has been jailbroken or rooted.
  bool? rooted;

  /// An unprocessed description string obtained by the operating system.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name and
  /// version from this string, if they are not explicitly given.
  String? rawDescription;

  /// Optional. Either light or dark.
  /// Describes whether the OS runs in dark mode or not.
  String? theme;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryOperatingSystem] from JSON [Map].
  factory SentryOperatingSystem.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryOperatingSystem(
      name: json.getValueOrNull('name'),
      version: json.getValueOrNull('version'),
      build: json.getValueOrNull('build'),
      kernelVersion: json.getValueOrNull('kernel_version'),
      rooted: json.getValueOrNull('rooted'),
      rawDescription: json.getValueOrNull('raw_description'),
      theme: json.getValueOrNull('theme'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (build != null) 'build': build,
      if (kernelVersion != null) 'kernel_version': kernelVersion,
      if (rooted != null) 'rooted': rooted,
      if (rawDescription != null) 'raw_description': rawDescription,
      if (theme != null) 'theme': theme,
    };
  }

  @Deprecated('Will be removed in a future version.')
  SentryOperatingSystem clone() => SentryOperatingSystem(
        name: name,
        version: version,
        build: build,
        kernelVersion: kernelVersion,
        rooted: rooted,
        rawDescription: rawDescription,
        theme: theme,
        unknown: unknown,
      );

  @Deprecated('Assign values directly to the instance.')
  SentryOperatingSystem copyWith({
    String? name,
    String? version,
    String? build,
    String? kernelVersion,
    bool? rooted,
    String? rawDescription,
    String? theme,
  }) =>
      SentryOperatingSystem(
        name: name ?? this.name,
        version: version ?? this.version,
        build: build ?? this.build,
        kernelVersion: kernelVersion ?? this.kernelVersion,
        rooted: rooted ?? this.rooted,
        rawDescription: rawDescription ?? this.rawDescription,
        theme: theme ?? this.theme,
        unknown: unknown,
      );

  SentryOperatingSystem mergeWith(SentryOperatingSystem other) =>
      SentryOperatingSystem(
        name: other.name ?? name,
        version: other.version ?? version,
        build: other.build ?? build,
        kernelVersion: other.kernelVersion ?? kernelVersion,
        rooted: other.rooted ?? rooted,
        rawDescription: other.rawDescription ?? rawDescription,
        theme: other.theme ?? theme,
        unknown: other.unknown == null
            ? unknown
            : unknown == null
                ? null
                : {...unknown!, ...other.unknown!},
      );
}
