import 'package:meta/meta.dart';

import 'access_aware_map.dart';
import 'sentry_id.dart';

class SentryFeedback {
  static const type = 'feedback';

  SentryFeedback({
    required this.message,
    this.contactEmail,
    this.name,
    this.replayId,
    this.url,
    this.associatedEventId,
    this.unknown,
  });

  String message;
  String? contactEmail;
  String? name;
  String? replayId;
  String? url;
  SentryId? associatedEventId;

  @internal
  final Map<String, dynamic>? unknown;

  /// Deserializes a [SentryFeedback] from JSON [Map].
  factory SentryFeedback.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);

    String? associatedEventId = json['associated_event_id'];

    return SentryFeedback(
      message: json['message'],
      contactEmail: json['contact_email'],
      name: json['name'],
      replayId: json['replay_id'],
      url: json['url'],
      associatedEventId:
          associatedEventId != null ? SentryId.fromId(associatedEventId) : null,
      unknown: json.notAccessed(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'message': message,
      if (contactEmail != null) 'contact_email': contactEmail,
      if (name != null) 'name': name,
      if (replayId != null) 'replay_id': replayId,
      if (url != null) 'url': url,
      if (associatedEventId != null)
        'associated_event_id': associatedEventId.toString(),
    };
  }

  @Deprecated('Assign values directly to the instance.')
  SentryFeedback copyWith({
    String? message,
    String? contactEmail,
    String? name,
    String? replayId,
    String? url,
    SentryId? associatedEventId,
    Map<String, dynamic>? unknown,
  }) =>
      SentryFeedback(
        message: message ?? this.message,
        contactEmail: contactEmail ?? this.contactEmail,
        name: name ?? this.name,
        replayId: replayId ?? this.replayId,
        url: url ?? this.url,
        associatedEventId: associatedEventId ?? this.associatedEventId,
        unknown: unknown ?? this.unknown,
      );

  @Deprecated('Will be removed in a future version.')
  SentryFeedback clone() => copyWith();
}
