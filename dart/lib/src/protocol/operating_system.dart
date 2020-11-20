/// Describes the operating system on which the event was created.
///
/// In web contexts, this is the operating system of the browse
/// (normally pulled from the User-Agent string).
class OperatingSystem {
  static const type = 'os';

  const OperatingSystem({
    this.name,
    this.version,
    this.build,
    this.kernelVersion,
    this.rooted,
    this.rawDescription,
  });

  factory OperatingSystem.fromJson(Map<String, dynamic> data) =>
      OperatingSystem(
        name: data['name'],
        version: data['version'],
        build: data['build'],
        kernelVersion: data['kernel_version'],
        rooted: data['rooted'],
        rawDescription: data['raw_description'],
      );

  /// The name of the operating system.
  final String name;

  /// The version of the operating system.
  final String version;

  /// The internal build revision of the operating system.
  final String build;

  /// An independent kernel version string.
  ///
  /// This is typically the entire output of the `uname` syscall.
  final String kernelVersion;

  /// A flag indicating whether the OS has been jailbroken or rooted.
  final bool rooted;

  /// An unprocessed description string obtained by the operating system.
  ///
  /// For some well-known runtimes, Sentry will attempt to parse name and
  /// version from this string, if they are not explicitly given.
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

  OperatingSystem clone() => OperatingSystem(
        name: name,
        version: version,
        build: build,
        kernelVersion: kernelVersion,
        rooted: rooted,
        rawDescription: rawDescription,
      );
}
