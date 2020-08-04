// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:http/testing.dart';
import 'package:http/http.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

const String testDsn = 'https://public:secret@sentry.example.com/1';
const String _testDsnWithoutSecret = 'https://public@sentry.example.com/1';
const String _testDsnWithPath =
    'https://public:secret@sentry.example.com/path/1';
const String _testDsnWithPort =
    'https://public:secret@sentry.example.com:8888/1';

void testHeaders(
  Map<String, String> headers,
  ClockProvider fakeClockProvider, {
  bool withUserAgent = true,
  bool compressPayload = true,
  bool withSecret = true,
}) {
  final expectedHeaders = <String, String>{
    'Content-Type': 'application/json',
    'X-Sentry-Auth': 'Sentry sentry_version=6, '
        'sentry_client=${SentryClient.sentryClient}, '
        'sentry_timestamp=${fakeClockProvider().millisecondsSinceEpoch}, '
        'sentry_key=public'
  };

  if (withSecret) {
    expectedHeaders['X-Sentry-Auth'] += ', '
        'sentry_secret=secret';
  }

  if (withUserAgent) expectedHeaders['User-Agent'] = '$sdkName/$sdkVersion';

  if (compressPayload) expectedHeaders['Content-Encoding'] = 'gzip';

  expect(headers, expectedHeaders);
}

void testCaptureException(
  bool compressPayload,
  Codec<List<int>, List<int>> gzip,
  bool isWeb,
) async {
  final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

  String postUri;
  Map<String, String> headers;
  List<int> body;
  final httpMock = MockClient((Request request) async {
    if (request.method == 'POST') {
      postUri = request.url.toString();
      headers = request.headers;
      body = request.bodyBytes;
      return Response('{"id": "test-event-id"}', 200);
    }
    fail('Unexpected request on ${request.method} ${request.url} in HttpMock');
  });

  final client = SentryClient(
    dsn: testDsn,
    httpClient: httpMock,
    clock: fakeClockProvider,
    uuidGenerator: () => 'X' * 32,
    compressPayload: compressPayload,
    environmentAttributes: const Event(
      serverName: 'test.server.com',
      release: '1.2.3',
      environment: 'staging',
    ),
  );

  try {
    throw ArgumentError('Test error');
  } catch (error, stackTrace) {
    final response =
        await client.captureException(exception: error, stackTrace: stackTrace);
    expect(response.isSuccessful, true);
    expect(response.eventId, 'test-event-id');
    expect(response.error, null);
  }

  expect(postUri, client.postUri);

  testHeaders(
    headers,
    fakeClockProvider,
    compressPayload: compressPayload,
    withUserAgent: !isWeb,
  );

  Map<String, dynamic> data;
  if (compressPayload) {
    data = json.decode(utf8.decode(gzip.decode(body)));
  } else {
    data = json.decode(utf8.decode(body));
  }
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

  if (isWeb) {
    // can't test the full url
    // the localhost port can change
    final absPathUri = Uri.parse(topFrame['abs_path']);
    expect(absPathUri.host, 'localhost');
    expect(absPathUri.path, '/sentry_browser_test.dart.browser_test.dart.js');

    expect(
      topFrame['filename'],
      'sentry_browser_test.dart.browser_test.dart.js',
    );
    expect(topFrame['function'], 'Object.wrapException');

    expect(data, {
      'project': '1',
      'event_id': 'X' * 32,
      'timestamp': '2017-01-02T00:00:00',
      'platform': 'javascript',
      'sdk': {'version': sdkVersion, 'name': 'sentry.dart'},
      'server_name': 'test.server.com',
      'release': '1.2.3',
      'environment': 'staging',
      'exception': [
        {'type': 'ArgumentError', 'value': 'Invalid argument(s): Test error'}
      ],
    });
  } else {
    expect(topFrame['abs_path'], 'test_utils.dart');
    expect(topFrame['filename'], 'test_utils.dart');
    expect(topFrame['function'], 'testCaptureException');

    expect(data, {
      'project': '1',
      'event_id': 'X' * 32,
      'timestamp': '2017-01-02T00:00:00',
      'platform': 'dart',
      'exception': [
        {'type': 'ArgumentError', 'value': 'Invalid argument(s): Test error'}
      ],
      'sdk': {'version': sdkVersion, 'name': 'sentry.dart'},
      'server_name': 'test.server.com',
      'release': '1.2.3',
      'environment': 'staging',
    });
  }

  expect(topFrame['lineno'], greaterThan(0));
  expect(topFrame['in_app'], true);

  await client.close();
}

void runTest({Codec<List<int>, List<int>> gzip, bool isWeb = false}) {
  test('can parse DSN', () async {
    final client = SentryClient(dsn: testDsn);
    expect(client.dsnUri, Uri.parse(testDsn));
    expect(client.postUri, 'https://sentry.example.com/api/1/store/');
    expect(client.publicKey, 'public');
    expect(client.secretKey, 'secret');
    expect(client.projectId, '1');
    await client.close();
  });

  test('can parse DSN without secret', () async {
    final client = SentryClient(dsn: _testDsnWithoutSecret);
    expect(client.dsnUri, Uri.parse(_testDsnWithoutSecret));
    expect(client.postUri, 'https://sentry.example.com/api/1/store/');
    expect(client.publicKey, 'public');
    expect(client.secretKey, null);
    expect(client.projectId, '1');
    await client.close();
  });

  test('can parse DSN with path', () async {
    final client = SentryClient(dsn: _testDsnWithPath);
    expect(client.dsnUri, Uri.parse(_testDsnWithPath));
    expect(client.postUri, 'https://sentry.example.com/path/api/1/store/');
    expect(client.publicKey, 'public');
    expect(client.secretKey, 'secret');
    expect(client.projectId, '1');
    await client.close();
  });
  test('can parse DSN with port', () async {
    final client = SentryClient(dsn: _testDsnWithPort);
    expect(client.dsnUri, Uri.parse(_testDsnWithPort));
    expect(client.postUri, 'https://sentry.example.com:8888/api/1/store/');
    expect(client.publicKey, 'public');
    expect(client.secretKey, 'secret');
    expect(client.projectId, '1');
    await client.close();
  });
  test('sends client auth header without secret', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    Map<String, String> headers;

    final httpMock = MockClient((Request request) async {
      if (request.method == 'POST') {
        headers = request.headers;
        return Response('{"id": "test-event-id"}', 200);
      }
      fail(
          'Unexpected request on ${request.method} ${request.url} in HttpMock');
    });

    final client = SentryClient(
      dsn: _testDsnWithoutSecret,
      httpClient: httpMock,
      clock: fakeClockProvider,
      compressPayload: false,
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
      final response = await client.captureException(
          exception: error, stackTrace: stackTrace);
      expect(response.isSuccessful, true);
      expect(response.eventId, 'test-event-id');
      expect(response.error, null);
    }

    testHeaders(
      headers,
      fakeClockProvider,
      withUserAgent: !isWeb,
      compressPayload: false,
      withSecret: false,
    );

    await client.close();
  });

  test('sends an exception report (compressed)', () async {
    await testCaptureException(true, gzip, isWeb);
  }, onPlatform: {
    'browser': Skip(),
  });

  test('sends an exception report (uncompressed)', () async {
    await testCaptureException(false, gzip, isWeb);
  });

  test('reads error message from the x-sentry-error header', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    final httpMock = MockClient((Request request) async {
      if (request.method == 'POST') {
        return Response('', 401, headers: <String, String>{
          'x-sentry-error': 'Invalid api key',
        });
      }
      fail(
          'Unexpected request on ${request.method} ${request.url} in HttpMock');
    });

    final client = SentryClient(
      dsn: testDsn,
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
      throw ArgumentError('Test error');
    } catch (error, stackTrace) {
      final response = await client.captureException(
          exception: error, stackTrace: stackTrace);
      expect(response.isSuccessful, false);
      expect(response.eventId, null);
      expect(
          response.error, 'Sentry.io responded with HTTP 401: Invalid api key');
    }

    await client.close();
  });

  test('$Event userContext overrides client', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    String loggedUserId; // used to find out what user context was sent
    final httpMock = MockClient((Request request) async {
      if (request.method == 'POST') {
        var bodyData = request.bodyBytes;
        var decoded = Utf8Codec().decode(bodyData);
        var decodedJson = JsonDecoder().convert(decoded);
        loggedUserId = decodedJson['user']['id'];
        return Response('', 401, headers: <String, String>{
          'x-sentry-error': 'Invalid api key',
        });
      }
      fail(
          'Unexpected request on ${request.method} ${request.url} in HttpMock');
    });

    final clientUserContext = User(
        id: 'client_user',
        username: 'username',
        email: 'email@email.com',
        ipAddress: '127.0.0.1');
    final eventUserContext = User(
        id: 'event_user',
        username: 'username',
        email: 'email@email.com',
        ipAddress: '127.0.0.1',
        extras: {'foo': 'bar'});

    final client = SentryClient(
      dsn: testDsn,
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
}
