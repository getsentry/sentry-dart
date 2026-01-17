import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import '../utils/type_safe_map_access.dart';

/// Carries information about the browser or user agent for web-related errors.
///
/// This can either be the browser this event ocurred in, or the user
/// agent of a web request that triggered the event.
class SentryBrowser {
  static const type = 'browser';

  /// Creates an instance of [SentryBrowser].
  SentryBrowser({this.name, this.version, this.unknown});

  /// Human readable application name, as it appears on the platform.
  String? name;

  /// Human readable application version, as it appears on the platform.
  String? version;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryBrowser] from JSON [Map].
  factory SentryBrowser.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryBrowser(
      name: json.getValueOrNull('name'),
      version: json.getValueOrNull('version'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
    };
  }

  @Deprecated('Will be removed in a future version.')
  SentryBrowser clone() => SentryBrowser(
        name: name,
        version: version,
        unknown: unknown,
      );

  @Deprecated('Assign values directly to the instance.')
  SentryBrowser copyWith({
    String? name,
    String? version,
  }) =>
      SentryBrowser(
        name: name ?? this.name,
        version: version ?? this.version,
        unknown: unknown,
      );
}
