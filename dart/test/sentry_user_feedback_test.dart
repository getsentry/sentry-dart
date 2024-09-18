import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_transport.dart';
import 'test_utils.dart';

void main() {
  group('$SentryUserFeedback', () {
    final id = SentryId.newId();

    final feedback = SentryUserFeedback(
      eventId: id,
      comments: 'this is awesome',
      email: 'sentry@example.com',
      name: 'Rockstar Developer',
      unknown: testUnknown,
    );
    final feedbackJson = <String, dynamic>{
      'event_id': id.toString(),
      'comments': 'this is awesome',
      'email': 'sentry@example.com',
      'name': 'Rockstar Developer',
    };
    feedbackJson.addAll(testUnknown);

    test('toJson', () {
      final json = feedback.toJson();
      expect(
        MapEquality().equals(feedbackJson, json),
        true,
      );
    });

    test('fromJson', () {
      final feedback = SentryRuntime.fromJson(feedbackJson);
      final json = feedback.toJson();

      expect(
        MapEquality().equals(feedbackJson, json),
        true,
      );
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

  group('$SentryUserFeedback to envelops', () {
    test('to envelope', () {
      final feedback = SentryUserFeedback(
        eventId: SentryId.newId(),
        name: 'test',
      );
      final envelope = SentryEnvelope.fromUserFeedback(
        feedback,
        SdkVersion(name: 'a', version: 'b'),
        dsn: fakeDsn,
      );

      expect(envelope.items.length, 1);
      expect(
        envelope.items.first.header.type,
        SentryItemType.userFeedback,
      );
      expect(envelope.header.eventId.toString(), feedback.eventId.toString());
      expect(envelope.header.dsn, fakeDsn);
    });
  });

  test('sending $SentryUserFeedback', () async {
    final fixture = Fixture();
    final sut = fixture.getSut();
    await sut.captureUserFeedback(SentryUserFeedback(
      eventId: SentryId.newId(),
      name: 'test',
    ));

    expect(fixture.transport.envelopes.length, 1);
  });

  test('cannot create $SentryUserFeedback with empty id', () async {
    expect(
      () => SentryUserFeedback(eventId: const SentryId.empty()),
      throwsA(isA<AssertionError>()),
    );
  });

  test('do not send $SentryUserFeedback when disabled', () async {
    final fixture = Fixture();
    final sut = fixture.getSut();
    await sut.close();
    await sut.captureUserFeedback(
      SentryUserFeedback(
        eventId: SentryId.newId(),
        name: 'test',
      ),
    );

    expect(fixture.transport.envelopes.length, 0);
  });

  test('do not send $SentryUserFeedback with empty id', () async {
    final fixture = Fixture();
    final sut = fixture.getSut();
    await sut.close();
    await sut.captureUserFeedback(
      SentryUserFeedbackWithoutAssert(
        eventId: SentryId.empty(),
      ),
    );

    expect(fixture.transport.envelopes.length, 0);
  });

  test('captureUserFeedback does not throw', () async {
    final options = defaultTestOptions()..automatedTestMode = false;
    final transport = ThrowingTransport();
    options.transport = transport;
    final sut = Hub(options);

    await expectLater(() async {
      await sut.captureUserFeedback(
        SentryUserFeedback(eventId: SentryId.newId(), name: 'name'),
      );
    }, returnsNormally);
  });
}

class Fixture {
  late MockTransport transport;

  Hub getSut() {
    final options = defaultTestOptions();
    transport = MockTransport();
    options.transport = transport;
    return Hub(options);
  }
}

// You cannot create an instance of SentryUserFeedback with an empty id.
// In order to test that UserFeedback with an empty id is not sent
// we need to implement it and remove the assert.
class SentryUserFeedbackWithoutAssert implements SentryUserFeedback {
  SentryUserFeedbackWithoutAssert({
    required this.eventId,
    this.name,
    this.email,
    this.comments,
    this.unknown,
  });

  @override
  final SentryId eventId;

  @override
  final String? name;

  @override
  final String? email;

  @override
  final String? comments;

  @override
  Map<String, dynamic>? unknown;

  @override
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'event_id': eventId.toString(),
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (comments != null) 'comments': comments,
    };
  }

  @override
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
