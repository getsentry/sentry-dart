import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'access_aware_map.dart';

/// Describes the current user associated with the application, such as the
/// currently signed in user.
///
/// The user can be specified globally in the [Scope.user] field,
/// or per event in the [SentryEvent.user] field.
///
/// You should provide at least one of [id], [email], [ipAddress], [username]
/// for Sentry to be able to tell you how many users are affected by one
/// issue, for example. Sending a user that has none of these attributes and
/// only custom attributes is valid, but not as useful.
///
/// Conforms to the User Interface contract for Sentry
/// https://develop.sentry.dev/sdk/event-payloads/user/
///
/// The outgoing JSON representation is:
///
/// ```
/// "user": {
///   "id": "unique_id",
///   "username": "my_user",
///   "email": "foo@example.com",
///   "ip_address": "127.0.0.1",
///   "segment": "segment"
/// }
/// ```
@immutable
class SentryUser {
  /// You should provide at least one of [id], [email], [ipAddress], [username]
  /// for Sentry to be able to tell you how many users are affected by one
  /// issue, for example. Sending a user that has none of these attributes and
  /// only custom attributes is valid, but not as useful.
  SentryUser({
    this.id,
    this.username,
    this.email,
    this.ipAddress,
    this.segment,
    this.geo,
    this.name,
    Map<String, dynamic>? data,
    @Deprecated('Will be removed in v8. Use [data] instead')
    Map<String, dynamic>? extras,
    this.unknown,
  })  : assert(
          id != null ||
              username != null ||
              email != null ||
              ipAddress != null ||
              segment != null,
        ),
        data = data == null ? null : Map.from(data),
        // ignore: deprecated_member_use_from_same_package
        extras = extras == null ? null : Map.from(extras);

  /// A unique identifier of the user.
  final String? id;

  /// The username of the user.
  final String? username;

  /// The email address of the user.
  final String? email;

  /// The IP of the user.
  final String? ipAddress;

  /// The user segment, for apps that divide users in user segments.
  @Deprecated(
      'Will be removed in v9. Use a custom tag or context instead to capture this information.')
  final String? segment;

  /// Any other user context information that may be helpful.
  ///
  /// These keys are stored as extra information but not specifically processed
  /// by Sentry.
  final Map<String, dynamic>? data;

  @Deprecated('Will be removed in v8. Use [data] instead')
  final Map<String, dynamic>? extras;

  /// Approximate geographical location of the end user or device.
  ///
  /// The geolocation is automatically inferred by Sentry.io if the [ipAddress] is set.
  /// Sentry however doesn't collect the [ipAddress] automatically because it is PII.
  /// The geo location will currently not be synced to the native layer, if available.
  // See https://github.com/getsentry/sentry-dart/issues/1065
  final SentryGeo? geo;

  /// Human readable name of the user.
  final String? name;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryUser] from JSON [Map].
  factory SentryUser.fromJson(Map<String, dynamic> jsonData) {
    final json = AccessAwareMap(jsonData);

    var extras = json['extras'];
    if (extras != null) {
      extras = Map<String, dynamic>.from(extras);
    }

    var data = json['data'];
    if (data != null) {
      data = Map<String, dynamic>.from(data);
    }

    SentryGeo? geo;
    final geoJson = json['geo'];
    if (geoJson != null) {
      geo = SentryGeo.fromJson(Map<String, dynamic>.from(geoJson));
    }
    return SentryUser(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      ipAddress: json['ip_address'],
      segment: json['segment'],
      data: data,
      geo: geo,
      name: json['name'],
      // ignore: deprecated_member_use_from_same_package
      extras: extras,
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final geoJson = geo?.toJson();
    return {
      ...?unknown,
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (ipAddress != null) 'ip_address': ipAddress,
      // ignore: deprecated_member_use_from_same_package
      if (segment != null) 'segment': segment,
      if (data?.isNotEmpty ?? false) 'data': data,
      // ignore: deprecated_member_use_from_same_package
      if (extras?.isNotEmpty ?? false) 'extras': extras,
      if (name != null) 'name': name,
      if (geoJson != null && geoJson.isNotEmpty) 'geo': geoJson,
    };
  }

  SentryUser copyWith({
    String? id,
    String? username,
    String? email,
    String? ipAddress,
    String? segment,
    @Deprecated('Will be removed in v8. Use [data] instead')
    Map<String, dynamic>? extras,
    String? name,
    SentryGeo? geo,
    Map<String, dynamic>? data,
  }) {
    return SentryUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      ipAddress: ipAddress ?? this.ipAddress,
      // ignore: deprecated_member_use_from_same_package
      segment: segment ?? this.segment,
      data: data ?? this.data,
      // ignore: deprecated_member_use_from_same_package
      extras: extras ?? this.extras,
      geo: geo ?? this.geo,
      name: name ?? this.name,
      unknown: unknown,
    );
  }
}
