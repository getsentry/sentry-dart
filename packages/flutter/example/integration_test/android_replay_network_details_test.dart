// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:jni/jni.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/java/binding.dart' as native;

/// Verifies on Android that captured network request/response detail (bodies
/// and headers) reaches the Session Replay recording, keeps the original body
/// size, and does not leak onto regular events or the breadcrumb itself.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';
  const requestSecret = 'request-secret-value';
  const responseSecret = 'response-secret-value';
  const requestBody = '{"password":"hunter2"}';
  // Larger than the 150 KB cap, so the captured body gets truncated while the
  // reported size must stay at the original length.
  final responseBody = jsonEncode({'data': 'x' * (200 * 1024)});

  group('Android replay network details', () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture(responseBody, responseSecret);
      await fixture.start(fakeDsn, requestSecret, responseSecret);
    });

    tearDown(() async {
      await fixture.dispose();
    });

    test(
      'bodies, headers and original size reach the replay recording',
      () async {
        await fixture.post(requestSecret, requestBody);

        final data = await fixture.replaySpanData();
        final request = data['request'] as Map<String, Object?>;
        final response = data['response'] as Map<String, Object?>;

        expect(request['size'], utf8.encode(requestBody).length);
        expect(jsonEncode(request), contains('hunter2'));
        expect(
          jsonEncode(request['headers']).toLowerCase(),
          contains(requestSecret),
        );

        // The body is truncated at the cap, but the size is the original one.
        expect(response['size'], utf8.encode(responseBody).length);
        expect(
          jsonEncode(response['headers']).toLowerCase(),
          contains(responseSecret),
        );
        expect(response['body'], isNotNull);
      },
      skip: !Platform.isAndroid,
    );

    test(
      'bodies and headers stay off the breadcrumb and regular events',
      () async {
        await fixture.post(requestSecret, requestBody);

        final breadcrumb = await fixture.nativeHttpBreadcrumb();
        final breadcrumbData = breadcrumb.data.toString();
        for (final secret in [requestSecret, responseSecret, 'hunter2']) {
          expect(breadcrumbData, isNot(contains(secret)));
        }

        await Sentry.captureException(Exception('regular event'));
        final event = jsonEncode(fixture.events.last.toJson());
        for (final secret in [requestSecret, responseSecret, 'hunter2']) {
          expect(event, isNot(contains(secret)));
        }
      },
      skip: !Platform.isAndroid,
    );
  });
}

class Fixture {
  Fixture(this._responseBody, this._responseSecret);

  final String _responseBody;
  final String _responseSecret;
  final events = <SentryEvent>[];
  late final HttpServer _server;
  late final http.Client _client;

  Future<void> start(
    String dsn,
    String requestSecret,
    String responseSecret,
  ) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      await request.drain<void>();
      request.response
        ..headers.contentType = ContentType.json
        ..headers.set('x-response-secret', _responseSecret)
        ..write(_responseBody);
      await request.response.close();
    });

    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..sendDefaultPii = true
        ..automatedTestMode = true
        ..beforeSend = (event, hint) {
          events.add(event);
          return null;
        };
      options.replay
        // Buffer mode: replay doesn't consume the network detail before the
        // test inspects it.
        ..sessionSampleRate = 0
        ..onErrorSampleRate = 1.0
        ..networkDetailAllowUrls.add('127.0.0.1')
        ..networkCaptureBodies = true
        ..networkRequestHeaders.add('x-request-secret')
        ..networkResponseHeaders.add('x-response-secret');
    });
    _client = SentryHttpClient(client: http.Client());
  }

  Future<void> post(String requestSecret, String body) async {
    final response = await _client.post(
      Uri.parse('http://127.0.0.1:${_server.port}/data'),
      headers: {
        'content-type': 'application/json',
        'x-request-secret': requestSecret,
      },
      body: body,
    );
    expect(response.statusCode, 200);
  }

  /// The native breadcrumb for the request, once it reached the native scope.
  Future<native.Breadcrumb> nativeHttpBreadcrumb() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final found = await _findNativeBreadcrumb();
      if (found != null) return found;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    fail('No native http breadcrumb after 10s');
  }

  Future<native.Breadcrumb?> _findNativeBreadcrumb() async {
    final completer = Completer<native.Breadcrumb?>();
    final callback = native.ScopeCallback.implement(
      native.$ScopeCallback(
        run: (iScope) {
          native.Breadcrumb? found;
          final queue = iScope.as(native.Scope.type).breadcrumbs;
          final iterator = queue.as(JCollection.type).iterator()!;
          while (iterator.hasNext()) {
            final crumb = iterator.next()?.as(native.Breadcrumb.type);
            if (crumb?.category?.toDartString(releaseOriginal: true) ==
                'http') {
              found = crumb;
            }
          }
          completer.complete(found);
        },
        run$async: true,
      ),
    );
    try {
      native.Sentry.configureScope(callback);
      return await completer.future;
    } finally {
      callback.release();
    }
  }

  /// Runs the breadcrumb through the replay converter, as the recorder does,
  /// and returns the network `data` of the resulting rrweb span event.
  Future<Map<String, Object?>> replaySpanData() async {
    final breadcrumb = await nativeHttpBreadcrumb();
    final replay =
        native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
    expect(replay, isNotNull);
    addTearDown(replay!.release);
    final event = replay.breadcrumbConverter.convert(breadcrumb);
    expect(event, isNotNull);
    final span = event!.as(native.RRWebSpanEvent.type);
    return _toDart(span.data) as Map<String, Object?>;
  }

  Future<void> dispose() async {
    _client.close();
    await _server.close(force: true);
    await Sentry.close();
  }
}

/// Recursively converts JNI collections/values to plain Dart ones.
Object? _toDart(JObject? object) {
  if (object == null) return null;
  if (object.isA(JString.type)) {
    return object.as(JString.type).toDartString();
  }
  if (object.isA(JBoolean.type)) {
    return object.as(JBoolean.type).toDartBool();
  }
  if (object.isA(JLong.type) ||
      object.isA(JInteger.type) ||
      object.isA(JShort.type)) {
    return object.as(JNumber.type).longValue();
  }
  if (object.isA(JDouble.type) || object.isA(JFloat.type)) {
    return object.as(JNumber.type).doubleValue();
  }
  if (object.isA(JMap.type)) {
    final map = object.as(JMap.type).asDart();
    return {
      for (final entry in map.entries)
        _toDart(entry.key).toString(): _toDart(entry.value),
    };
  }
  if (object.isA(JList.type)) {
    return object.as(JList.type).asDart().map(_toDart).toList();
  }
  return object.toString();
}
