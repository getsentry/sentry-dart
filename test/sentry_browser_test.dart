// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn("browser")
import 'dart:convert';

import 'package:http/http.dart';
import 'package:sentry/browser_client.dart';
import 'package:test/test.dart';

const String _testDsn = 'https://public:secret@sentry.example.com/1';
const String _testDsnWithoutSecret = 'https://public@sentry.example.com/1';
const String _testDsnWithPath =
    'https://public:secret@sentry.example.com/path/1';
const String _testDsnWithPort =
    'https://public:secret@sentry.example.com:8888/1';
void main() {
  group('$SentryBrowserClient', () {
    test('can parse DSN', () async {
      final SentryBrowserClient client = SentryBrowserClient(dsn: _testDsn);
      expect(client.dsnUri, Uri.parse(_testDsn));
      expect(client.postUri, 'https://sentry.example.com/api/1/store/');
      expect(client.publicKey, 'public');
      expect(client.secretKey, 'secret');
      expect(client.projectId, '1');
      await client.close();
    });

    test('can parse DSN without secret', () async {
      final SentryBrowserClient client =
          SentryBrowserClient(dsn: _testDsnWithoutSecret);
      expect(client.dsnUri, Uri.parse(_testDsnWithoutSecret));
      expect(client.postUri, 'https://sentry.example.com/api/1/store/');
      expect(client.publicKey, 'public');
      expect(client.secretKey, null);
      expect(client.projectId, '1');
      await client.close();
    });

    test('can parse DSN with path', () async {
      final SentryBrowserClient client =
          SentryBrowserClient(dsn: _testDsnWithPath);
      expect(client.dsnUri, Uri.parse(_testDsnWithPath));
      expect(client.postUri, 'https://sentry.example.com/path/api/1/store/');
      expect(client.publicKey, 'public');
      expect(client.secretKey, 'secret');
      expect(client.projectId, '1');
      await client.close();
    });
    test('can parse DSN with port', () async {
      final SentryBrowserClient client =
          SentryBrowserClient(dsn: _testDsnWithPort);
      expect(client.dsnUri, Uri.parse(_testDsnWithPort));
      expect(client.postUri, 'https://sentry.example.com:8888/api/1/store/');
      expect(client.publicKey, 'public');
      expect(client.secretKey, 'secret');
      expect(client.projectId, '1');
      await client.close();
    });
    test('sends client auth header without secret', () async {
      final MockClient httpMock = MockClient();
      final ClockProvider fakeClockProvider = () => DateTime.utc(2017, 1, 2);

      Map<String, String> headers;

      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          headers = invocation.namedArguments[#headers];
          return Response('{"id": "test-event-id"}', 200);
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final SentryBrowserClient client = SentryBrowserClient(
        dsn: _testDsnWithoutSecret,
        httpClient: httpMock,
        clock: fakeClockProvider,
        uuidGenerator: () => 'X' * 32,
        environmentAttributes: const Event(
          serverName: 'test.server.com',
          release: '1.2.3',
          environment: 'staging',
        ),
      );

      try {
        throw ArgumentError('Test error');
      } catch (error, stackTrace) {
        final SentryResponse response = await client.captureException(
            exception: error, stackTrace: stackTrace);
        expect(response.isSuccessful, true);
        expect(response.eventId, 'test-event-id');
        expect(response.error, null);
      }

      final Map<String, String> expectedHeaders = <String, String>{
        'Content-Type': 'application/json',
        'X-Sentry-Auth': 'Sentry sentry_version=6, '
            'sentry_client=${SentryClient.sentryClient}, '
            'sentry_timestamp=${fakeClockProvider().millisecondsSinceEpoch}, '
            'sentry_key=public',
      };

      expect(headers, expectedHeaders);

      await client.close();
    });

    testCaptureException() async {
      final MockClient httpMock = MockClient();
      final ClockProvider fakeClockProvider = () => DateTime.utc(2017, 1, 2);

      String postUri;
      Map<String, String> headers;
      List<int> body;
      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          postUri = invocation.positionalArguments.single;
          headers = invocation.namedArguments[#headers];
          body = invocation.namedArguments[#body];
          return Response('{"id": "test-event-id"}', 200);
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final SentryBrowserClient client = SentryBrowserClient(
        dsn: _testDsn,
        httpClient: httpMock,
        clock: fakeClockProvider,
        uuidGenerator: () => 'X' * 32,
        environmentAttributes: const Event(
          serverName: 'test.server.com',
          release: '1.2.3',
          environment: 'staging',
        ),
      );

      try {
        throw ArgumentError('Test error');
      } catch (error, stackTrace) {
        final SentryResponse response = await client.captureException(
            exception: error, stackTrace: stackTrace);
        expect(response.isSuccessful, true);
        expect(response.eventId, 'test-event-id');
        expect(response.error, null);
      }

      expect(postUri, client.postUri);

      final Map<String, String> expectedHeaders = <String, String>{
        'Content-Type': 'application/json',
        'X-Sentry-Auth': 'Sentry sentry_version=6, '
            'sentry_client=${SentryClient.sentryClient}, '
            'sentry_timestamp=${fakeClockProvider().millisecondsSinceEpoch}, '
            'sentry_key=public, '
            'sentry_secret=secret',
      };

      expect(headers, expectedHeaders);

      Map<String, dynamic> data = json.decode(utf8.decode(body));

      final Map<String, dynamic> stacktrace = data.remove('stacktrace');
      expect(stacktrace['frames'], const TypeMatcher<List>());
      expect(stacktrace['frames'], isNotEmpty);

      final Map<String, dynamic> topFrame =
          (stacktrace['frames'] as Iterable<dynamic>).last;
      expect(topFrame.keys, <String>[
        'abs_path',
        'function',
        'lineno',
        'colno',
        'in_app',
        'filename',
      ]);

      // can't test full url, local PORT can change
      expect(topFrame['abs_path'].startsWith('http://localhost:'), isTrue);
      expect(
        topFrame['abs_path']
            .endsWith('/sentry_browser_test.dart.browser_test.dart.js'),
        isTrue,
      );
      expect(topFrame['function'], 'Object.wrapException');
      expect(topFrame['lineno'], greaterThan(0));
      expect(topFrame['in_app'], true);
      expect(topFrame['filename'], 'sentry_browser_test.dart.browser_test.dart.js');

      expect(data, {
        'project': '1',
        'event_id': 'X' * 32,
        'timestamp': '2017-01-02T00:00:00',
        'platform': 'javascript',
        'exception': [
          {'type': 'ArgumentError', 'value': 'Invalid argument(s): Test error'}
        ],
        'sdk': {'version': sdkVersion, 'name': 'dart'},
        'logger': 'SentryClient',
        'server_name': 'test.server.com',
        'release': '1.2.3',
        'environment': 'staging',
      });

      await client.close();
    }

    test('sends an exception report (uncompressed)', () async {
      await testCaptureException();
    });

    test('reads error message from the x-sentry-error header', () async {
      final MockClient httpMock = MockClient();
      final ClockProvider fakeClockProvider = () => DateTime.utc(2017, 1, 2);

      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          return Response('', 401, headers: <String, String>{
            'x-sentry-error': 'Invalid api key',
          });
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final SentryBrowserClient client = SentryBrowserClient(
        dsn: _testDsn,
        httpClient: httpMock,
        clock: fakeClockProvider,
        uuidGenerator: () => 'X' * 32,
        environmentAttributes: const Event(
          serverName: 'test.server.com',
          release: '1.2.3',
          environment: 'staging',
        ),
      );

      try {
        throw ArgumentError('Test error');
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
      final MockClient httpMock = MockClient();
      final ClockProvider fakeClockProvider = () => DateTime.utc(2017, 1, 2);

      String loggedUserId; // used to find out what user context was sent
      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          // parse the body and detect which user context was sent
          var bodyData = invocation.namedArguments[Symbol("body")];
          var decoded = Utf8Codec().decode(bodyData);
          var decodedJson = JsonDecoder().convert(decoded);
          loggedUserId = decodedJson['user']['id'];
          return Response('', 401, headers: <String, String>{
            'x-sentry-error': 'Invalid api key',
          });
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final clientUserContext = User(
          id: "client_user",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1");
      final eventUserContext = User(
          id: "event_user",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1",
          extras: {"foo": "bar"});

      final SentryBrowserClient client = SentryBrowserClient(
        dsn: _testDsn,
        httpClient: httpMock,
        clock: fakeClockProvider,
        uuidGenerator: () => 'X' * 32,
        environmentAttributes: const Event(
          serverName: 'test.server.com',
          release: '1.2.3',
          environment: 'staging',
        ),
      );
      client.userContext = clientUserContext;

      try {
        throw ArgumentError('Test error');
      } catch (error, stackTrace) {
        final eventWithoutContext =
            Event(exception: error, stackTrace: stackTrace);
        final eventWithContext = Event(
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
    test('$Breadcrumb serializes', () {
      expect(
        Breadcrumb(
          "example log",
          DateTime.utc(2019),
          level: SeverityLevel.debug,
          category: "test",
        ).toJson(),
        <String, dynamic>{
          'timestamp': '2019-01-01T00:00:00',
          'message': 'example log',
          'category': 'test',
          'level': 'debug',
        },
      );
    });
    test('serializes to JSON', () {
      final user = User(
          id: "user_id",
          username: "username",
          email: "email@email.com",
          ipAddress: "127.0.0.1",
          extras: {"foo": "bar"});

      final breadcrumbs = [
        Breadcrumb("test log", DateTime.utc(2019),
            level: SeverityLevel.debug, category: "test"),
      ];

      expect(
        Event(
          message: 'test-message',
          transaction: '/test/1',
          exception: StateError('test-error'),
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
          breadcrumbs: breadcrumbs,
        ).toJson(),
        <String, dynamic>{
          'platform': 'dart',
          'sdk': {'version': sdkVersion, 'name': 'dart'},
          'message': 'test-message',
          'transaction': '/test/1',
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
          'breadcrumbs': {
            'values': [
              {
                'timestamp': '2019-01-01T00:00:00',
                'message': 'test log',
                'category': 'test',
                'level': 'debug',
              },
            ]
          },
        },
      );
    });
  });
}

typedef Answer = dynamic Function(Invocation invocation);

class MockClient implements Client {
  Answer _answer;

  void answerWith(Answer answer) {
    _answer = answer;
  }

  noSuchMethod(Invocation invocation) {
    return _answer(invocation);
  }
}
