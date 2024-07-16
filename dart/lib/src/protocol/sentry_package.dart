import 'package:meta/meta.dart';

import 'unknown.dart';

/// A [SentryPackage] part of the SDK.
@immutable
class SentryPackage {
  /// Creates an [SentryPackage] object that is part of the SDK.
  const SentryPackage(this.name, this.version, {this.unknown});

  /// The name of the SDK.
  final String name;

  /// The version of the SDK.
  final String version;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryPackage] from JSON [Map].
  factory SentryPackage.fromJson(Map<String, dynamic> json) {
    return SentryPackage(
      json['name'],
      json['version'],
      unknown: unknownFrom(json, {'name', 'version'}),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      ...?unknown,
    };
  }

  SentryPackage copyWith({
    String? name,
    String? version,
  }) =>
      SentryPackage(
        name ?? this.name,
        version ?? this.version,
        unknown: unknown,
      );
}
