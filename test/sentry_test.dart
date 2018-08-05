// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

const String _testDsn = 'https://public:secret@sentry.example.com/1';

void main() {
  group('$SentryClient', () {
    test('reads error message from the x-sentry-error header', () async {
      final MockClient httpMock = new MockClient();
      final ClockProvider fakeClockProvider =
          () => new DateTime.utc(2017, 1, 2);

      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          return new Response('', 401, headers: <String, String>{
            'x-sentry-error': 'Invalid api key',
          });
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final SentryClient client = new SentryClient(
        dsn: _testDsn,
        httpClient: httpMock,
        clock: fakeClockProvider,
        uuidGenerator: () => 'X' * 32,
        compressPayload: false,
        environmentAttributes: const Event(
          serverName: 'test.server.com',
          release: '1.2.3',
          environment: 'staging',
        ),
      );

      try {
        throw new ArgumentError('Test error');
      } catch (error, stackTrace) {
        final SentryResponse response = await client.captureException(
            exception: error, stackTrace: stackTrace);
        expect(response.isSuccessful, false);
        expect(response.eventId, null);
        expect(response.error,
            'Sentry.io responded with HTTP 401: Invalid api key');
      }

      await client.close();
    });

    test('$Event userContext overrides client', () async {
      final MockClient httpMock = new MockClient();
      final ClockProvider fakeClockProvider =
          () => new DateTime.utc(2017, 1, 2);

      String loggedUserId; // used to find out what user context was sent
      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          // parse the body and detect which user context was sent
          var bodyData = invocation.namedArguments[new Symbol("body")];
          var decoded = new Utf8Codec().decode(bodyData);
          var decodedJson = new JsonDecoder().convert(decoded);
          loggedUserId = decodedJson['user']['id'];
          return new Response('', 401, headers: <String, String>{
            'x-sentry-error': 'Invalid api key',
          });
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final clientUserContext = new User(
          id: "client_user",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1");
      final eventUserContext = new User(
          id: "event_user",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1",
          extras: {"foo": "bar"});

      final SentryClient client = new SentryClient(
        dsn: _testDsn,
        httpClient: httpMock,
        clock: fakeClockProvider,
        uuidGenerator: () => 'X' * 32,
        compressPayload: false,
        environmentAttributes: const Event(
          serverName: 'test.server.com',
          release: '1.2.3',
          environment: 'staging',
        ),
      );
      client.userContext = clientUserContext;

      try {
        throw new ArgumentError('Test error');
      } catch (error, stackTrace) {
        final eventWithoutContext =
            new Event(exception: error, stackTrace: stackTrace);
        final eventWithContext = new Event(
            exception: error,
            stackTrace: stackTrace,
            userContext: eventUserContext);
        await client.capture(event: eventWithoutContext);
        expect(loggedUserId, clientUserContext.id);
        await client.capture(event: eventWithContext);
        expect(loggedUserId, eventUserContext.id);
      }

      await client.close();
    });
  });

  group('$Event', () {
    test('serializes to JSON', () {
      final user = new User(
          id: "user_id",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1",
          extras: {"foo": "bar"});
      expect(
        new Event(
          message: 'test-message',
          exception: new StateError('test-error'),
          level: SeverityLevel.debug,
          culprit: 'Professor Moriarty',
          tags: <String, String>{
            'a': 'b',
            'c': 'd',
          },
          extra: <String, dynamic>{
            'e': 'f',
            'g': 2,
          },
          fingerprint: <String>[Event.defaultFingerprint, 'foo'],
          userContext: user,
        ).toJson(),
        <String, dynamic>{
          'sdk': {'version': sdkVersion, 'name': 'dart'},
          'message': 'test-message',
          'exception': [
            {'type': 'StateError', 'value': 'Bad state: test-error'}
          ],
          'level': 'debug',
          'culprit': 'Professor Moriarty',
          'tags': {'a': 'b', 'c': 'd'},
          'extra': {'e': 'f', 'g': 2},
          'fingerprint': ['{{ default }}', 'foo'],
          'user': {
            'id': 'user_id',
            'username': 'username',
            'email': 'email@email.com',
            'ip_address': '127.0.0.1',
            'extras': {'foo': 'bar'}
          },
        },
      );
    });
  });
}
