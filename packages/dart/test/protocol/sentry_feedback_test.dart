import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final associatedEventId = SentryId.fromId('8a32c0f9be1d34a5efb2c4a10d80de9a');

  final feedback = SentryFeedback(
    message: 'fixture-message',
    contactEmail: 'fixture-contactEmail',
    name: 'fixture-name',
    replayId: 'fixture-replayId',
    url: "https://fixture-url.com",
    associatedEventId: associatedEventId,
    unknown: testUnknown,
  );

  final feedbackJson = <String, dynamic>{
    'message': 'fixture-message',
    'contact_email': 'fixture-contactEmail',
    'name': 'fixture-name',
    'replay_id': 'fixture-replayId',
    'url': 'https://fixture-url.com',
    'associated_event_id': '8a32c0f9be1d34a5efb2c4a10d80de9a',
  };
  feedbackJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = feedback.toJson();

      expect(
        MapEquality().equals(feedbackJson, json),
        true,
      );
    });
    test('fromJson', () {
      final feedback = SentryFeedback.fromJson(feedbackJson);
      final json = feedback.toJson();

      print(feedback);
      print(json);

      expect(
        MapEquality().equals(feedbackJson, json),
        true,
      );
    });
  });
}
