import 'package:meta/meta.dart';

import 'unknown.dart';

/// Describes the operating system on which the event was created.
///
/// In web contexts, this is the operating system of the browse
/// (normally pulled from the User-Agent string).
@immutable
class SentryOperatingSystem {
  static const type = 'os';

  const SentryOperatingSystem({
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
  final String? name;

  /// The version of the operating system.
  final String? version;

  /// The internal build revision of the operating system.
  final String? build;

  /// An independent kernel version string.
  ///
  /// This is typically the entire output of the `uname` syscall.
  final String? kernelVersion;

  /// A flag indicating whether the OS has been jailbroken or rooted.
  final bool? rooted;

  /// An unprocessed description string obtained by the operating system.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name and
  /// version from this string, if they are not explicitly given.
  final String? rawDescription;

  /// Optional. Either light or dark.
  /// Describes whether the OS runs in dark mode or not.
  final String? theme;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryOperatingSystem] from JSON [Map].
  factory SentryOperatingSystem.fromJson(Map<String, dynamic> data) =>
      SentryOperatingSystem(
        name: data['name'],
        version: data['version'],
        build: data['build'],
        kernelVersion: data['kernel_version'],
        rooted: data['rooted'],
        rawDescription: data['raw_description'],
        theme: data['theme'],
        unknown: unknownFrom(data, {
          'name',
          'version',
          'build',
          'kernel_version',
          'rooted',
          'raw_description',
          'theme',
        }),
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (build != null) 'build': build,
      if (kernelVersion != null) 'kernel_version': kernelVersion,
      if (rooted != null) 'rooted': rooted,
      if (rawDescription != null) 'raw_description': rawDescription,
      if (theme != null) 'theme': theme,
    };
    json.addAll(unknown ?? {});
    return json;
  }

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
}
