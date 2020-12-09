import 'package:meta/meta.dart';

/// A [SentryPackage] part of the [Sdk].
@immutable
class SentryPackage {
  /// Creates an [SentryPackage] object that is part of the [Sdk].
  const SentryPackage(this.name, this.version)
      : assert(name != null && version != null);

  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, String>{
      'name': name,
      'version': version,
    };
  }

  SentryPackage copyWith({
    String name,
    String version,
  }) =>
      SentryPackage(
        name ?? this.name,
        version ?? this.version,
      );
}
