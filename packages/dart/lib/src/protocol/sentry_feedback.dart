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
  factory SentryFeedback.fromJson(Map<String, Object?> data) {
    final json = AccessAwareMap(data);

    final associatedEventId = json.readString('associated_event_id');

    return SentryFeedback(
      // Required by the constructor: feedback without a message is not
      // feedback, so the caller drops this child and keeps the raw JSON.
      message: json.readString('message')!,
      contactEmail: json.readString('contact_email'),
      name: json.readString('name'),
      replayId: json.readString('replay_id'),
      url: json.readString('url'),
      associatedEventId: associatedEventId != null
          ? SentryId.fromId(associatedEventId)
          : null,
      unknown: json.notAccessed(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'message': message,
      'contact_email': ?contactEmail,
      'name': ?name,
      'replay_id': ?replayId,
      'url': ?url,
      'associated_event_id': ?associatedEventId?.toString(),
    };
  }
}
