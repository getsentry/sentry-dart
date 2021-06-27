import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryUserFeedback', () {
    test('toJson', () {
      final id = SentryId.newId();
      final feedback = SentryUserFeedback(
        eventId: id,
        comments: 'this is awesome',
        email: 'sentry@example.com',
        name: 'Rockstar Developer',
      );
      expect(feedback.toJson(), {
        'event_id': id.toString(),
        'comments': 'this is awesome',
        'email': 'sentry@example.com',
        'name': 'Rockstar Developer',
      });
    });

    test('fromJson', () {
      final id = SentryId.newId();
      final feedback = SentryUserFeedback.fromJson({
        'event_id': id.toString(),
        'comments': 'this is awesome',
        'email': 'sentry@example.com',
        'name': 'Rockstar Developer',
      });

      expect(feedback.eventId.toString(), id.toString());
      expect(feedback.comments, 'this is awesome');
      expect(feedback.email, 'sentry@example.com');
      expect(feedback.name, 'Rockstar Developer');
    });

    test('copyWith', () {
      final id = SentryId.newId();
      final feedback = SentryUserFeedback(
        eventId: id,
        comments: 'this is awesome',
        email: 'sentry@example.com',
        name: 'Rockstar Developer',
      );

      final copyId = SentryId.newId();
      final copy = feedback.copyWith(
        eventId: copyId,
        comments: 'actually it is not',
        email: 'example@example.com',
        name: '10x developer',
      );

      expect(copy.eventId.toString(), copyId.toString());
      expect(copy.comments, 'actually it is not');
      expect(copy.email, 'example@example.com');
      expect(copy.name, '10x developer');
    });

    test('disallow empty id', () {
      final id = SentryId.empty();
      expect(() => SentryUserFeedback(eventId: id),
          throwsA(isA<AssertionError>()));
    });
  });
}
