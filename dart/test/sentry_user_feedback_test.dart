import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_transport.dart';
import 'test_utils.dart';

void main() {
  // ignore: deprecated_member_use_from_same_package
  group('$SentryUserFeedback', () {
    final id = SentryId.newId();

    // ignore: deprecated_member_use_from_same_package
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
      // ignore: deprecated_member_use_from_same_package
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
      // ignore: deprecated_member_use_from_same_package
      expect(() => SentryUserFeedback(eventId: id),
          throwsA(isA<AssertionError>()));
    });
  });

  // ignore: deprecated_member_use_from_same_package
  group('$SentryUserFeedback to envelops', () {
    test('to envelope', () {
      // ignore: deprecated_member_use_from_same_package
      final feedback = SentryUserFeedback(
        eventId: SentryId.newId(),
        name: 'test',
      );
      // ignore: deprecated_member_use_from_same_package
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

  // ignore: deprecated_member_use_from_same_package
  test('sending $SentryUserFeedback', () async {
    final fixture = Fixture();
    final sut = fixture.getSut();
    // ignore: deprecated_member_use_from_same_package
    await sut.captureUserFeedback(SentryUserFeedback(
      eventId: SentryId.newId(),
      name: 'test',
    ));

    expect(fixture.transport.envelopes.length, 1);
  });

  // ignore: deprecated_member_use_from_same_package
  test('cannot create $SentryUserFeedback with empty id', () async {
    expect(
      // ignore: deprecated_member_use_from_same_package
      () => SentryUserFeedback(eventId: const SentryId.empty()),
      throwsA(isA<AssertionError>()),
    );
  });

  // ignore: deprecated_member_use_from_same_package
  test('do not send $SentryUserFeedback when disabled', () async {
    final fixture = Fixture();
    final sut = fixture.getSut();
    await sut.close();
    // ignore: deprecated_member_use_from_same_package
    await sut.captureUserFeedback(
      // ignore: deprecated_member_use_from_same_package
      SentryUserFeedback(
        eventId: SentryId.newId(),
        name: 'test',
      ),
    );

    expect(fixture.transport.envelopes.length, 0);
  });

  // ignore: deprecated_member_use_from_same_package
  test('do not send $SentryUserFeedback with empty id', () async {
    final fixture = Fixture();
    final sut = fixture.getSut();
    await sut.close();
    // ignore: deprecated_member_use_from_same_package
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
      // ignore: deprecated_member_use_from_same_package
      await sut.captureUserFeedback(
        // ignore: deprecated_member_use_from_same_package
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
// ignore: deprecated_member_use_from_same_package
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
  // ignore: deprecated_member_use_from_same_package
  SentryUserFeedback copyWith({
    SentryId? eventId,
    String? name,
    String? email,
    String? comments,
  }) {
    // ignore: deprecated_member_use_from_same_package
    return SentryUserFeedback(
      eventId: eventId ?? this.eventId,
      name: name ?? this.name,
      email: email ?? this.email,
      comments: comments ?? this.comments,
      unknown: unknown,
    );
  }
}
