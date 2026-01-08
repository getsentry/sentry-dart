import '../../protocol/sentry_runtime.dart';

// The Flutter version information can be fetched via Dart defines,
// see
//  - https://github.com/flutter/flutter/pull/140783
//  - https://github.com/flutter/flutter/pull/163761
//
// This code lives in the Dart only Sentry code, since the code
// doesn't require any Flutter dependency.
// Additionally, this makes it work on background isolates in
// Flutter, where one may not initialize the whole Flutter Sentry
// SDK.
// The const-ness of the properties below ensure that the code
// is tree shaken in a non-Flutter environment.

const _isFlutterRuntimeInformationAbsent = FlutterVersion.version == null ||
    FlutterVersion.channel == null ||
    FlutterVersion.frameworkRevision == null;

final SentryRuntime? flutterRuntime = _isFlutterRuntimeInformationAbsent
    ? null
    : SentryRuntime(
        name: 'Flutter',
        version: '${FlutterVersion.version} (${FlutterVersion.channel})',
        build: FlutterVersion.frameworkRevision,
        rawDescription: '${FlutterVersion.version} (${FlutterVersion.channel}) '
            '- Git hash ${FlutterVersion.frameworkRevision} '
            '- Git URL ${FlutterVersion.gitUrl}',
      );

final SentryRuntime? dartFlutterRuntime = FlutterVersion.dartVersion == null
    ? null
    : SentryRuntime(name: 'Dart', version: FlutterVersion.dartVersion);

/// Details about the Flutter version this app was compiled with,
/// corresponding to the output of `flutter --version`.
///
/// When this Flutter version was build from a fork, or when Flutter runs in a
/// custom embedder, these values might be unreliable.
abstract class FlutterVersion {
  const FlutterVersion._();

  /// The Flutter version used to compile the app.
  static const String? version = bool.hasEnvironment('FLUTTER_VERSION')
      ? String.fromEnvironment('FLUTTER_VERSION')
      : null;

  /// The Flutter channel used to compile the app.
  static const String? channel = bool.hasEnvironment('FLUTTER_CHANNEL')
      ? String.fromEnvironment('FLUTTER_CHANNEL')
      : null;

  /// The URL of the Git repository from which Flutter was obtained.
  static const String? gitUrl = bool.hasEnvironment('FLUTTER_GIT_URL')
      ? String.fromEnvironment('FLUTTER_GIT_URL')
      : null;

  /// The Flutter framework revision, as a (short) Git commit ID.
  static const String? frameworkRevision =
      bool.hasEnvironment('FLUTTER_FRAMEWORK_REVISION')
          ? String.fromEnvironment('FLUTTER_FRAMEWORK_REVISION')
          : null;

  /// The Flutter engine revision.
  static const String? engineRevision =
      bool.hasEnvironment('FLUTTER_ENGINE_REVISION')
          ? String.fromEnvironment('FLUTTER_ENGINE_REVISION')
          : null;

  // This is included since [Platform.version](https://api.dart.dev/stable/dart-io/Platform/version.html)
  // is not included on web platforms.
  /// The Dart version used to compile the app.
  static const String? dartVersion = bool.hasEnvironment('FLUTTER_DART_VERSION')
      ? String.fromEnvironment('FLUTTER_DART_VERSION')
      : null;

  /// Parses [version] into components for comparison.
  ///
  /// Returns `null` if the version string is malformed.
  ///
  /// Examples:
  /// - "3.33.0" -> FlutterVersionComponents(3, 33)
  /// - "4.0.0-pre.1" -> FlutterVersionComponents(4, 0)
  /// - "3.24" -> FlutterVersionComponents(3, 24)
  /// - "invalid" -> null
  static FlutterVersionComponents? parseComponents(String version) {
    final dot = version.indexOf('.');
    if (dot == -1) return null;

    final major = int.tryParse(version.substring(0, dot));
    if (major == null) return null;

    final nextDot = version.indexOf('.', dot + 1);
    final minorEnd = nextDot == -1 ? version.length : nextDot;
    final minor = int.tryParse(version.substring(dot + 1, minorEnd));
    if (minor == null) return null;

    return FlutterVersionComponents(major, minor);
  }
}

/// Parsed Flutter version components for comparison.
class FlutterVersionComponents {
  final int major;
  final int minor;

  const FlutterVersionComponents(this.major, this.minor);

  /// Returns `true` if this version meets or exceeds the minimum requirement.
  ///
  /// Example:
  /// ```dart
  /// final version = FlutterVersion.parseComponents('3.33.0');
  /// if (version?.meetsMinimum(3, 33) ?? false) {
  ///   // Flutter 3.33+ feature available
  /// }
  /// ```
  bool meetsMinimum(int minMajor, int minMinor) =>
      major > minMajor || (major == minMajor && minor >= minMinor);

  @override
  bool operator ==(Object other) =>
      other is FlutterVersionComponents &&
      other.major == major &&
      other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => 'FlutterVersionComponents($major, $minor)';
}
