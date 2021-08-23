import 'package:meta/meta.dart';

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
/// https://docs.sentry.io/clientdev/interfaces/user/.
///
/// The outgoing JSON representation is:
///
/// ```
/// "user": {
///   "id": "unique_id",
///   "username": "my_user",
///   "email": "foo@example.com",
///   "ip_address": "127.0.0.1",
///   "subscription": "basic"
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
    Map<String, dynamic>? extras,
  })  : assert(id != null ||
            username != null ||
            email != null ||
            ipAddress != null),
        extras = extras == null ? null : Map.from(extras);

  /// A unique identifier of the user.
  final String? id;

  /// The username of the user.
  final String? username;

  /// The email address of the user.
  final String? email;

  /// The IP of the user.
  final String? ipAddress;

  /// Any other user context information that may be helpful.
  ///
  /// These keys are stored as extra information but not specifically processed
  /// by Sentry.
  final Map<String, dynamic>? extras;

  /// Deserializes a [SentryUser] from JSON [Map].
  factory SentryUser.fromJson(Map<String, dynamic> json) {
    return SentryUser(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      ipAddress: json['ip_address'],
      extras: json['extras'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (email != null) 'email': email,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (extras?.isNotEmpty ?? false) 'extras': extras,
    };
  }

  SentryUser copyWith({
    String? id,
    String? username,
    String? email,
    String? ipAddress,
    Map<String, dynamic>? extras,
  }) =>
      SentryUser(
        id: id ?? this.id,
        username: username ?? this.username,
        email: email ?? this.email,
        ipAddress: ipAddress ?? this.ipAddress,
        extras: extras ?? this.extras,
      );
}
