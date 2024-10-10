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

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = feedback;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });
    test('copyWith takes new values', () {
      final data = feedback;

      final copy = data.copyWith(
        message: 'fixture-2-message',
        contactEmail: 'fixture-2-contactEmail',
        name: 'fixture-2-name',
        replayId: 'fixture-2-replayId',
        url: "https://fixture-2-url.com",
        associatedEventId: SentryId.fromId('1d49af08b6e2c437f9052b1ecfd83dca'),
      );

      expect(copy.message, 'fixture-2-message');
      expect(copy.contactEmail, 'fixture-2-contactEmail');
      expect(copy.name, 'fixture-2-name');
      expect(copy.replayId, 'fixture-2-replayId');
      expect(copy.url, "https://fixture-2-url.com");
      expect(copy.associatedEventId.toString(),
          '1d49af08b6e2c437f9052b1ecfd83dca');
    });
  });
}
