// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/version.dart';
import 'package:test/test.dart';

const String testDsn = 'https://public:secret@sentry.example.com/1';
const String _testDsnWithoutSecret = 'https://public@sentry.example.com/1';
const String _testDsnWithPath =
    'https://public:secret@sentry.example.com/path/1';
const String _testDsnWithPort =
    'https://public:secret@sentry.example.com:8888/1';

void testHeaders(
  Map<String, String>? headers,
  ClockProvider fakeClockProvider, {
  String? sdkName,
  bool withUserAgent = true,
  bool compressPayload = true,
  bool withSecret = true,
}) {
  final expectedHeaders = <String, String>{
    'Content-Type': 'application/x-sentry-envelope',
    'X-Sentry-Auth': 'Sentry sentry_version=7, '
        'sentry_client=$sdkName/$sdkVersion, '
        'sentry_key=public'
  };

  if (withSecret) {
    expectedHeaders['X-Sentry-Auth'] =
        '${expectedHeaders['X-Sentry-Auth']!}, sentry_secret=secret';
  }

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
  Codec<List<int>, List<int>?>? gzip,
  bool isWeb,
) async {
  final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

  Uri? postUri;
  Map<String, String>? headers;
  List<int>? body;
  final httpMock = MockClient((http.Request request) async {
    if (request.method == 'POST') {
      postUri = request.url;
      headers = request.headers;
      body = request.bodyBytes;
      return http.Response('{"id": "test-event-id"}', 200);
    }
    fail('Unexpected request on ${request.method} ${request.url} in HttpMock');
  });

  final options = SentryOptions(dsn: testDsn)
    ..compressPayload = compressPayload
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

  final dsn = Dsn.parse(options.dsn!);
  expect(postUri, dsn.postUri);

  testHeaders(
    headers,
    fakeClockProvider,
    compressPayload: compressPayload,
    withUserAgent: !isWeb,
    sdkName: sdkName(isWeb),
  );

  String envelopeData;
  if (compressPayload) {
    envelopeData = utf8.decode(gzip!.decode(body));
  } else {
    envelopeData = utf8.decode(body!);
  }
  final eventJson = envelopeData.split('\n').last;
  final data = json.decode(eventJson) as Map<String, dynamic>?;

  // so we assert the generated and returned id
  data!['event_id'] = sentryId.toString();

  final stacktrace = data['exception']['values'].first['stacktrace'];

  expect(stacktrace['frames'], const TypeMatcher<List>());
  expect(stacktrace['frames'], isNotEmpty);

  final topFrame =
      (stacktrace['frames'] as Iterable<dynamic>).last as Map<String, dynamic>;
  expect(
    topFrame.keys,
    <String>['filename', 'function', 'lineno', 'colno', 'abs_path', 'in_app'],
  );

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

    expect(data['event_id'], sentryId.toString());
    expect(data['timestamp'], '2017-01-02T00:00:00.000Z');
    expect(data['platform'], 'javascript');
    expect(data['sdk'], {
      'version': sdkVersion,
      'name': sdkName(isWeb),
      'packages': [
        {'name': 'pub:sentry', 'version': sdkVersion}
      ]
    });
    expect(data['server_name'], 'test.server.com');
    expect(data['release'], '1.2.3');
    expect(data['environment'], 'staging');

    expect(data['exception']['values'].first['type'], 'ArgumentError');
    expect(data['exception']['values'].first['value'],
        'Invalid argument(s): Test error');
  } else {
    expect(topFrame['abs_path'], 'test_utils.dart');
    expect(topFrame['filename'], 'test_utils.dart');
    expect(topFrame['function'], 'testCaptureException');

    expect(data['event_id'], sentryId.toString());
    expect(data['timestamp'], '2017-01-02T00:00:00.000Z');
    expect(data['platform'], 'other');
    expect(data['sdk'], {
      'version': sdkVersion,
      'name': 'sentry.dart',
      'packages': [
        {'name': 'pub:sentry', 'version': sdkVersion}
      ]
    });
    expect(data['server_name'], 'test.server.com');
    expect(data['release'], '1.2.3');
    expect(data['environment'], 'staging');
    expect(data['exception']['values'].first['type'], 'ArgumentError');
    expect(data['exception']['values'].first['value'],
        'Invalid argument(s): Test error');
  }

  expect(topFrame['lineno'], greaterThan(0));
  expect(topFrame['in_app'], true);

  client.close();
}

void runTest({Codec<List<int>, List<int>?>? gzip, bool isWeb = false}) {
  test('can parse DSN', () async {
    final options = SentryOptions(dsn: testDsn);
    final client = SentryClient(options);

    final dsn = Dsn.parse(options.dsn!);

    expect(dsn.uri, Uri.parse(testDsn));
    expect(
      dsn.postUri,
      Uri.parse('https://sentry.example.com/api/1/envelope/'),
    );
    expect(dsn.publicKey, 'public');
    expect(dsn.secretKey, 'secret');
    expect(dsn.projectId, '1');
    client.close();
  });

  test('can parse DSN without secret', () async {
    final options = SentryOptions(dsn: _testDsnWithoutSecret);
    final client = SentryClient(options);

    final dsn = Dsn.parse(options.dsn!);

    expect(dsn.uri, Uri.parse(_testDsnWithoutSecret));
    expect(
      dsn.postUri,
      Uri.parse('https://sentry.example.com/api/1/envelope/'),
    );
    expect(dsn.publicKey, 'public');
    expect(dsn.secretKey, null);
    expect(dsn.projectId, '1');
    client.close();
  });

  test('can parse DSN with path', () async {
    final options = SentryOptions(dsn: _testDsnWithPath);
    final client = SentryClient(options);

    final dsn = Dsn.parse(options.dsn!);

    expect(dsn.uri, Uri.parse(_testDsnWithPath));
    expect(
      dsn.postUri,
      Uri.parse('https://sentry.example.com/path/api/1/envelope/'),
    );
    expect(dsn.publicKey, 'public');
    expect(dsn.secretKey, 'secret');
    expect(dsn.projectId, '1');
    client.close();
  });
  test('can parse DSN with port', () async {
    final options = SentryOptions(dsn: _testDsnWithPort);
    final client = SentryClient(options);

    final dsn = Dsn.parse(options.dsn!);

    expect(dsn.uri, Uri.parse(_testDsnWithPort));
    expect(
      dsn.postUri,
      Uri.parse('https://sentry.example.com:8888/api/1/envelope/'),
    );
    expect(dsn.publicKey, 'public');
    expect(dsn.secretKey, 'secret');
    expect(dsn.projectId, '1');
    client.close();
  });
  test('sends client auth header without secret', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    Map<String, String>? headers;

    final httpMock = MockClient((http.Request request) async {
      if (request.method == 'POST') {
        headers = request.headers;
        return http.Response('{"id": "testeventid"}', 200);
      }
      fail(
        'Unexpected request on ${request.method} ${request.url} in HttpMock',
      );
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
      sdkName: sdkName(isWeb),
    );

    client.close();
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

    final httpMock = MockClient((http.Request request) async {
      if (request.method == 'POST') {
        return http.Response('', 401, headers: <String, String>{
          'x-sentry-error': 'Invalid api key',
        });
      }
      fail(
        'Unexpected request on ${request.method} ${request.url} in HttpMock',
      );
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

    client.close();
  });

  test('$SentryEvent user overrides client', () async {
    final fakeClockProvider = () => DateTime.utc(2017, 1, 2);

    String? loggedUserId; // used to find out what user context was sent
    final httpMock = MockClient((http.Request request) async {
      if (request.method == 'POST') {
        final bodyData = request.bodyBytes;
        final decoded = const Utf8Codec().decode(bodyData);
        final eventJson = decoded.split('\n').last;
        final dynamic decodedJson = json.decode(eventJson);

        loggedUserId = decodedJson['user']['id'] as String?;
        return http.Response(
          '',
          401,
          headers: <String, String>{
            'x-sentry-error': 'Invalid api key',
          },
        );
      }
      fail(
        'Unexpected request on ${request.method} ${request.url} in HttpMock',
      );
    });

    final clientUser = SentryUser(
      id: 'client_user',
      username: 'username',
      email: 'email@email.com',
      ipAddress: '127.0.0.1',
    );
    final eventUser = SentryUser(
      id: 'event_user',
      username: 'username',
      email: 'email@email.com',
      ipAddress: '127.0.0.1',
      data: <String, String>{'foo': 'bar'},
    );

    final options = SentryOptions(
      dsn: testDsn,
    )
      ..httpClient = httpMock
      ..clock = fakeClockProvider
      ..compressPayload = false
      ..serverName = 'test.server.com'
      ..release = '1.2.3'
      ..environment = 'staging'
      ..sendClientReports = false;

    final client = SentryClient(options);

    try {
      throw ArgumentError('Test error');
    } catch (error) {
      final eventWithoutContext = SentryEvent(
        eventId: SentryId.empty(),
        throwable: error,
      );
      final eventWithContext = SentryEvent(
        eventId: SentryId.empty(),
        throwable: error,
        user: eventUser,
      );

      final scope = Scope(options);
      await scope.setUser(clientUser);

      await client.captureEvent(
        eventWithoutContext,
        scope: scope,
      );
      expect(loggedUserId, clientUser.id);

      final secondScope = Scope(options);
      await secondScope.setUser(clientUser);

      await client.captureEvent(
        eventWithContext,
        scope: secondScope,
      );
      expect(loggedUserId, eventUser.id);
    }

    client.close();
  });
}
