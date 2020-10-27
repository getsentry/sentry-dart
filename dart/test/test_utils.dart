// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
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
  String sdkName,
  bool withUserAgent = true,
  bool compressPayload = true,
  bool withSecret = true,
}) {
  final expectedHeaders = <String, String>{
    'Content-Type': 'application/json',
    'X-Sentry-Auth': 'Sentry sentry_version=6, '
        'sentry_client=$sdkName/$sdkVersion, '
        'sentry_key=public, '
  };

  if (withSecret) {
    expectedHeaders['X-Sentry-Auth'] += 'sentry_secret=secret, ';
  }

  expectedHeaders['X-Sentry-Auth'] +=
      'sentry_timestamp=${fakeClockProvider().millisecondsSinceEpoch}';

  if (withUserAgent) {
    expectedHeaders['User-Agent'] = '$sdkName/$sdkVersion';
  }

  if (compressPayload) {
    expectedHeaders['Content-Encoding'] = 'gzip';
  }

  expect(headers, expectedHeaders);
}

Future testCaptureException(
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

  final options = SentryOptions(dsn: testDsn)
    ..clock = fakeClockProvider
    ..httpClient = httpMock
    ..serverName = 'test.server.com'
    ..release = '1.2.3'
    ..environment = 'staging';

  var sentryId = SentryId.empty();
  final client = SentryClient(options);

  try {
    throw ArgumentError('Test error');
  } catch (error, stackTrace) {
    sentryId = await client.captureException(error, stackTrace: stackTrace);
    expect('$sentryId', 'testeventid');
  }

  expect(postUri, options.transport.dsn.postUri);

  testHeaders(
    headers,
    fakeClockProvider,
    compressPayload: compressPayload,
    withUserAgent: !isWeb,
    sdkName: sdkName,
  );

  Map<String, dynamic> data;
  if (compressPayload) {
    data = json.decode(utf8.decode(gzip.decode(body))) as Map<String, dynamic>;
  } else {
    data = json.decode(utf8.decode(body)) as Map<String, dynamic>;
  }

  // so we assert the generated and returned id
  data['event_id'] = sentryId.toString();

  final stacktrace = data.remove('stacktrace') as Map<String, dynamic>;

  expect(stacktrace['frames'], const TypeMatcher<List>());
  expect(stacktrace['frames'], isNotEmpty);

  final topFrame =
      (stacktrace['frames'] as Iterable<dynamic>).last as Map<String, dynamic>;
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
    final absPathUri = Uri.parse(topFrame['abs_path'] as String);
    expect(absPathUri.host, 'localhost');
    expect(absPathUri.path, '/sentry_browser_test.dart.browser_test.dart.js');

    expect(
      topFrame['filename'],
      'sentry_browser_test.dart.browser_test.dart.js',
    );
    expect(topFrame['function'], 'Object.wrapException');

    expect(data, {
      'event_id': sentryId.toString(),
      'timestamp': '2017-01-02T00:00:00',
      'platform': 'javascript',
      'sdk': {'version': sdkVersion, 'name': sdkName},
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
      'event_id': sentryId.toString(),
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
    final options = SentryOptions(dsn: testDsn);
    final client = SentryClient(options);
    expect(options.transport.dsn.uri, Uri.parse(testDsn));
    expect(
      options.transport.dsn.postUri,
      'https://sentry.example.com/api/1/store/',
    );
    expect(options.transport.dsn.publicKey, 'public');
    expect(options.transport.dsn.secretKey, 'secret');
    expect(options.transport.dsn.projectId, '1');
    await client.close();
  });

  test('can parse DSN without secret', () async {
    final options = SentryOptions(dsn: _testDsnWithoutSecret);
    final client = SentryClient(options);
    expect(options.transport.dsn.uri, Uri.parse(_testDsnWithoutSecret));
    expect(
      options.transport.dsn.postUri,
      'https://sentry.example.com/api/1/store/',
    );
    expect(options.transport.dsn.publicKey, 'public');
    expect(options.transport.dsn.secretKey, null);
    expect(options.transport.dsn.projectId, '1');
    await client.close();
  });

  test('can parse DSN with path', () async {
    final options = SentryOptions(dsn: _testDsnWithPath);
    final client = SentryClient(options);
    expect(options.transport.dsn.uri, Uri.parse(_testDsnWithPath));
    expect(
      options.transport.dsn.postUri,
      'https://sentry.example.com/path/api/1/store/',
    );
    expect(options.transport.dsn.publicKey, 'public');
    expect(options.transport.dsn.secretKey, 'secret');
    expect(options.transport.dsn.projectId, '1');
    await client.close();
  });
  test('can parse DSN with port', () async {
    final options = SentryOptions(dsn: _testDsnWithPort);
    final client = SentryClient(options);
    expect(options.transport.dsn.uri, Uri.parse(_testDsnWithPort));
    expect(
      options.transport.dsn.postUri,
      'https://sentry.example.com:8888/api/1/store/',
    );
    expect(options.transport.dsn.publicKey, 'public');
    expect(options.transport.dsn.secretKey, 'secret');
    expect(options.transport.dsn.projectId, '1');
    await client.close();
  });
  test('sends client auth header without secret', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    Map<String, String> headers;

    final httpMock = MockClient((Request request) async {
      if (request.method == 'POST') {
        headers = request.headers;
        return Response('{"id": "testeventid"}', 200);
      }
      fail(
          'Unexpected request on ${request.method} ${request.url} in HttpMock');
    });

    final client = SentryClient(
      SentryOptions(dsn: _testDsnWithoutSecret)
        ..httpClient = httpMock
        ..clock = fakeClockProvider
        ..compressPayload = false
        ..serverName = 'test.server.com'
        ..release = '1.2.3'
        ..environment = 'staging',
    );

    try {
      throw ArgumentError('Test error');
    } catch (error, stackTrace) {
      final sentryId =
          await client.captureException(error, stackTrace: stackTrace);
      expect('$sentryId', 'testeventid');
    }

    testHeaders(
      headers,
      fakeClockProvider,
      withUserAgent: !isWeb,
      compressPayload: false,
      withSecret: false,
      sdkName: sdkName,
    );

    await client.close();
  });

  test('sends an exception report (compressed)', () async {
    await testCaptureException(true, gzip, isWeb);
  }, onPlatform: <String, Skip>{
    'browser': const Skip(),
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
      SentryOptions(
        dsn: testDsn,
      )
        ..httpClient = httpMock
        ..clock = fakeClockProvider
        ..compressPayload = false
        ..serverName = 'test.server.com'
        ..release = '1.2.3'
        ..environment = 'staging',
    );

    try {
      throw ArgumentError('Test error');
    } catch (error, stackTrace) {
      final sentryId =
          await client.captureException(error, stackTrace: stackTrace);
      expect('$sentryId', '00000000000000000000000000000000');
    }

    await client.close();
  });

  test('$SentryEvent userContext overrides client', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    String loggedUserId; // used to find out what user context was sent
    final httpMock = MockClient((Request request) async {
      if (request.method == 'POST') {
        final bodyData = request.bodyBytes;
        final decoded = const Utf8Codec().decode(bodyData);
        final dynamic decodedJson = const JsonDecoder().convert(decoded);
        loggedUserId = decodedJson['user']['id'] as String;
        return Response('', 401, headers: <String, String>{
          'x-sentry-error': 'Invalid api key',
        });
      }
      fail(
          'Unexpected request on ${request.method} ${request.url} in HttpMock');
    });

    const clientUserContext = User(
      id: 'client_user',
      username: 'username',
      email: 'email@email.com',
      ipAddress: '127.0.0.1',
    );
    const eventUserContext = User(
      id: 'event_user',
      username: 'username',
      email: 'email@email.com',
      ipAddress: '127.0.0.1',
      extras: <String, String>{'foo': 'bar'},
    );

    final options = SentryOptions(
      dsn: testDsn,
    )
      ..httpClient = httpMock
      ..clock = fakeClockProvider
      ..compressPayload = false
      ..serverName = 'test.server.com'
      ..release = '1.2.3'
      ..environment = 'staging';

    final client = SentryClient(options);

    try {
      throw ArgumentError('Test error');
    } catch (error, stackTrace) {
      final eventWithoutContext = SentryEvent(
        eventId: SentryId.empty(),
        exception: error,
        stackTrace: stackTrace,
      );
      final eventWithContext = SentryEvent(
        eventId: SentryId.empty(),
        exception: error,
        stackTrace: stackTrace,
        userContext: eventUserContext,
      );
      await client.captureEvent(eventWithoutContext,
          scope: Scope(options)..user = clientUserContext);
      expect(loggedUserId, clientUserContext.id);
      await client.captureEvent(
        eventWithContext,
        scope: Scope(options)..user = clientUserContext,
      );
      expect(loggedUserId, eventUserContext.id);
    }

    await client.close();
  });
}
