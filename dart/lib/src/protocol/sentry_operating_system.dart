import 'package:meta/meta.dart';

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

  /// Deserializes a [SentryOperatingSystem] from JSON [Map].
  // ignore: strict_raw_type
  factory SentryOperatingSystem.fromJson(Map data) => SentryOperatingSystem(
        // This class should be deserializable from Map<String, dynamic> and Map<Object?, Object?>,
        // because it comes from json.decode which is a Map<String, dynamic> and from
        // methodchannels which is a Map<Object?, Object?>.
        // Map<String, dynamic> and Map<Object?, Object?> only have
        // Map<dynamic, dynamic> as common type constraint
        name: data['name'] as String?,
        version: data['version'] as String?,
        build: data['build'] as String?,
        kernelVersion: data['kernel_version'] as String?,
        rooted: data['rooted'] as bool?,
        rawDescription: data['raw_description'] as String?,
      );

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (name != null) {
      json['name'] = name;
    }

    if (version != null) {
      json['version'] = version;
    }

    if (build != null) {
      json['build'] = build;
    }

    if (kernelVersion != null) {
      json['kernel_version'] = kernelVersion;
    }

    if (rooted != null) {
      json['rooted'] = rooted;
    }

    if (rawDescription != null) {
      json['raw_description'] = rawDescription;
    }

    return json;
  }

  SentryOperatingSystem clone() => SentryOperatingSystem(
        name: name,
        version: version,
        build: build,
        kernelVersion: kernelVersion,
        rooted: rooted,
        rawDescription: rawDescription,
      );

  SentryOperatingSystem copyWith({
    String? name,
    String? version,
    String? build,
    String? kernelVersion,
    bool? rooted,
    String? rawDescription,
  }) =>
      SentryOperatingSystem(
        name: name ?? this.name,
        version: version ?? this.version,
        build: build ?? this.build,
        kernelVersion: kernelVersion ?? this.kernelVersion,
        rooted: rooted ?? this.rooted,
        rawDescription: rawDescription ?? this.rawDescription,
      );
}
