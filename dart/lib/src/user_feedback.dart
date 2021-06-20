import 'protocol.dart';

class UserFeedback {
  UserFeedback({
    required this.eventId,
    this.name,
    this.email,
    this.comments,
  });

  factory UserFeedback.fromJson(Map<String, dynamic> json) {
    return UserFeedback(
      eventId: json['event_id'],
      name: json['name'],
      email: json['email'],
      comments: json['comments'],
    );
  }

  /// The eventId of the event to which the user feedback is associated.
  final SentryId eventId;

  /// Recommended: The name of the user.
  final String? name;

  /// Recommended: The name of the user.
  final String? email;

  /// Recommended: Comments of the user about what happened.
  final String? comments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'event_id': eventId.toString(),
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (comments != null) 'comments': comments,
    };
  }

  UserFeedback copyWith({
    SentryId? eventId,
    String? name,
    String? email,
    String? comments,
  }) {
    return UserFeedback(
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      email: email ?? this.email,
      comments: comments ?? this.comments,
    );
  }
}
