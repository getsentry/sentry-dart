import 'package:meta/meta.dart';

import '../../sentry.dart';

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
    this.subscription,
    this.geo,
    this.name,
    Map<String, dynamic>? data,
    @Deprecated('Will be removed in v7. Use data instead')
        Map<String, dynamic>? extras,
  })  : assert(
          id != null ||
              username != null ||
              email != null ||
              ipAddress != null ||
              segment != null,
        ),
        assert(data == null || extras == null, 'Only use one of data/extra'),
        data = (data ?? extras) == null ? null : Map.from(data ?? extras ?? {});

  /// A unique identifier of the user.
  final String? id;

  /// The username of the user.
  final String? username;

  /// The email address of the user.
  final String? email;

  /// The IP of the user.
  final String? ipAddress;

  /// The user segment, for apps that divide users in user segments.
  final String? segment;

  /// Any other user context information that may be helpful.
  ///
  /// These keys are stored as extra information but not specifically processed
  /// by Sentry.
  final Map<String, dynamic>? data;

  @Deprecated('Will be removed in v7. Use [data] instead')
  Map<String, dynamic>? get extras => data;

  final String? subscription;

  /// Approximate geographical location of the end user or device.
  final SentryGeo? geo;

  /// Human readable name of the user.
  final String? name;

  /// Deserializes a [SentryUser] from JSON [Map].
  factory SentryUser.fromJson(Map<String, dynamic> json) {
    var extras = json['extras'] as Map<String, dynamic>?;
    if (extras != null) {
      extras = Map<String, dynamic>.from(extras);
    }

    var data = json['data'] as Map<String, dynamic>?;
    if (data != null) {
      data = Map<String, dynamic>.from(data);
    }

    SentryGeo? geo;
    final geoJson = json['geo'] as Map<String, dynamic>?;
    if (geoJson != null) {
      geo = SentryGeo.fromJson(geoJson);
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
      subscription: json['subscription'],
      // ignore: deprecated_member_use_from_same_package
      extras: extras,
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    final geoJson = geo?.toJson();
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (segment != null) 'segment': segment,
      if (data?.isNotEmpty ?? false) 'data': data,
      if (subscription != null) 'subscription': subscription,
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
    @Deprecated('Will be removed in v7. Use [data] instead')
        Map<String, dynamic>? extras,
    String? name,
    String? subscription,
    SentryGeo? geo,
    Map<String, dynamic>? data,
  }) {
    assert(data == null || extras == null, 'Only use one of data/extra');
    return SentryUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      ipAddress: ipAddress ?? this.ipAddress,
      segment: segment ?? this.segment,
      // ignore: deprecated_member_use_from_same_package
      data: (data ?? extras) ?? (this.data ?? this.extras),
      geo: geo ?? this.geo,
      name: name ?? this.name,
    );
  }
}
