import 'package:meta/meta.dart';

/// Carries information about the browser or user agent for web-related errors.
///
/// This can either be the browser this event ocurred in, or the user
/// agent of a web request that triggered the event.
@immutable
class SentryBrowser {
  static const type = 'browser';

  /// Creates an instance of [SentryBrowser].
  const SentryBrowser({this.name, this.version});

  factory SentryBrowser.fromJson(Map<String, dynamic> data) => SentryBrowser(
        name: data['name'],
        version: data['version'],
      );

  /// Human readable application name, as it appears on the platform.
  final String? name;

  /// Human readable application version, as it appears on the platform.
  final String? version;

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (name != null) {
      json['name'] = name;
    }

    if (version != null) {
      json['version'] = version;
    }

    return json;
  }

  SentryBrowser clone() => SentryBrowser(name: name, version: version);

  SentryBrowser copyWith({
    String? name,
    String? version,
  }) =>
      SentryBrowser(
        name: name ?? this.name,
        version: version ?? this.version,
      );
}
