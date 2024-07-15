import 'package:meta/meta.dart';

import 'protocol.dart';
import 'protocol/unknown.dart';

class SentryUserFeedback {
  SentryUserFeedback({
    required this.eventId,
    this.name,
    this.email,
    this.comments,
    this.unknown,
  }) : assert(eventId != SentryId.empty() &&
            (name?.isNotEmpty == true ||
                email?.isNotEmpty == true ||
                comments?.isNotEmpty == true));

  factory SentryUserFeedback.fromJson(Map<String, dynamic> json) {
    return SentryUserFeedback(
      eventId: SentryId.fromId(json['event_id']),
      name: json['name'],
      email: json['email'],
      comments: json['comments'],
      unknown: unknownFrom(json, {
        'event_id',
        'name',
        'email',
        'comments',
      }),
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

  @internal
  final Map<String, dynamic>? unknown;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'event_id': eventId.toString(),
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (comments != null) 'comments': comments,
    };
    if (unknown != null) {
      json.addAll(unknown ?? {});
    }
    return json;
  }

  SentryUserFeedback copyWith({
    SentryId? eventId,
    String? name,
    String? email,
    String? comments,
  }) {
    return SentryUserFeedback(
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      email: email ?? this.email,
      comments: comments ?? this.comments,
      unknown: unknown,
    );
  }
}
