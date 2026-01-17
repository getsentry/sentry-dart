import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// A [SentryPackage] part of the SDK.
class SentryPackage {
  /// Creates an [SentryPackage] object that is part of the SDK.
  SentryPackage(this.name, this.version, {this.unknown});

  /// The name of the SDK.
  String name;

  /// The version of the SDK.
  String version;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryPackage] from JSON [Map].
  factory SentryPackage.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryPackage(
      json.getValueOrNull('name')!,
      json.getValueOrNull('version')!,
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'name': name,
      'version': version,
    };
  }

  @Deprecated('Assign values directly to the instance.')
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
