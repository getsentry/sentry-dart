// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn("browser")
import 'dart:convert';
import 'dart:html' hide Event;

import 'package:http/http.dart';
import 'package:sentry/sentry_browser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

const String _testDsn = 'https://public:secret@sentry.example.com/1';
const String _testDsnWithoutSecret = 'https://public@sentry.example.com/1';

void main() {
  group('$SentryClientBrowser', () {
    test('can parse DSN', () async {
      final SentryClientBase client = new SentryClientBrowser(dsn: _testDsn);
      testDsn(client, _testDsn);
      await client.close();
    });

    test('can parse DSN without secret', () async {
      final SentryClientBase client =
          new SentryClientBrowser(dsn: _testDsnWithoutSecret);
      testDsn(client, _testDsnWithoutSecret, withSecret: false);
      await client.close();
    });

    test('sends client auth header without secret and without user agent',
        () async {
      final MockClient httpMock = new MockClient();
      final ClockProvider fakeClockProvider =
          () => new DateTime.utc(2017, 1, 2);

      Map<String, String> headers;

      httpMock.answerWith((Invocation invocation) async {
        if (invocation.memberName == #close) {
          return null;
        }
        if (invocation.memberName == #post) {
          headers = invocation.namedArguments[#headers];
          return new Response('{"id": "test-event-id"}', 200);
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final SentryClientBase client = new SentryClientBrowser(
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
        throw new ArgumentError('Test error');
      } catch (error, stackTrace) {
        final SentryResponse response = await client.captureException(
            exception: error, stackTrace: stackTrace);
        expect(response.isSuccessful, true);
        expect(response.eventId, 'test-event-id');
        expect(response.error, null);
      }

      testHeaders(
        headers,
        fakeClockProvider,
        withUserAgent: false,
        compressPayload: false,
        withSecret: false,
      );

      await client.close();
    });

    testCaptureException() async {
      final MockClient httpMock = new MockClient();
      final ClockProvider fakeClockProvider =
          () => new DateTime.utc(2017, 1, 2);

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
          return new Response('{"id": "test-event-id"}', 200);
        }
        fail('Unexpected invocation of ${invocation.memberName} in HttpMock');
      });

      final SentryClientBase client = new SentryClientBrowser(
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
        throw new ArgumentError('Test error');
      } catch (error, stackTrace) {
        final SentryResponse response = await client.captureException(
            exception: error, stackTrace: stackTrace);
        expect(response.isSuccessful, true);
        expect(response.eventId, 'test-event-id');
        expect(response.error, null);
      }

      expect(postUri, client.postUri);

      testHeaders(
        headers,
        fakeClockProvider,
        withUserAgent: false,
        compressPayload: false,
      );

      final Map<String, dynamic> data = json.decode(utf8.decode(body));
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
        'filename'
      ]);
      expect(topFrame['abs_path'],
          '${window.location.origin}/sentry_browser_test.dart.browser_test.dart.js');
      // fixme: the function name should be 'main.<fn>.testCaptureException'
      // but it is not due to javascript stacktrace
      // find a way to correctly test that
      expect(topFrame['function'], 'Object.wrapException');
      expect(topFrame['lineno'], greaterThan(0));
      expect(topFrame['colno'], greaterThan(0));
      expect(topFrame['in_app'], true);
      expect(topFrame['filename'],
          'sentry_browser_test.dart.browser_test.dart.js');

      expect(data, {
        'project': '1',
        'event_id': 'X' * 32,
        'timestamp': '2017-01-02T00:00:00',
        'exception': [
          {'type': 'ArgumentError', 'value': 'Invalid argument(s): Test error'}
        ],
        'sdk': {'version': sdkVersion, 'name': 'dart'},
        'logger': SentryClientBase.defaultLoggerName,
        'server_name': 'test.server.com',
        'release': '1.2.3',
        'environment': 'staging',
        'platform': 'javascript',
      });

      await client.close();
    }

    test('sends an exception report', () async {
      await testCaptureException();
    });
  });
}
