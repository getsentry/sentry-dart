import 'package:meta/meta.dart';

import 'unknown.dart';

/// Carries information about the browser or user agent for web-related errors.
///
/// This can either be the browser this event ocurred in, or the user
/// agent of a web request that triggered the event.
@immutable
class SentryBrowser {
  static const type = 'browser';

  /// Creates an instance of [SentryBrowser].
  const SentryBrowser({this.name, this.version, this.unknown});

  /// Human readable application name, as it appears on the platform.
  final String? name;

  /// Human readable application version, as it appears on the platform.
  final String? version;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryBrowser] from JSON [Map].
  factory SentryBrowser.fromJson(Map<String, dynamic> data) => SentryBrowser(
      name: data['name'],
      version: data['version'],
      unknown: unknownFrom(data, {'name', 'version'}));

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      if (name != null) 'name': name,
      if (version != null) 'version': version,
    };
    json.addAll(unknown ?? {});
    return json;
  }

  SentryBrowser clone() => SentryBrowser(
        name: name,
        version: version,
        unknown: unknown,
      );

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
