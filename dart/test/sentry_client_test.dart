import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('SentryClient captures message', () {
    SentryOptions options;

    String formattedMessage;
    String template;
    List<dynamic> params;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.compressPayload = false;
      options.httpClient = MockClient((request) async {
        if (request.method == 'POST') {
          final body = const JsonDecoder()
              .convert(Utf8Codec().decode(request.bodyBytes));

          formattedMessage = body['message']['formatted'];
          template = body['message']['message'];
          params = body['message']['params'];

          return Response('{"id": "test-event-id"}', 200);
        }
        fail(
          'Unexpected request on ${request.method} ${request.url} in HttpMock',
        );
      });
    });

    test('should captures message', () async {
      final client = SentryClient(options);
      await client.captureMessage(
        'simple message 1',
        template: 'simple message %d',
        params: [1],
        level: SentryLevel.error,
      );
      expect(formattedMessage, 'simple message 1');
      expect(template, 'simple message %d');
      expect(params, [1]);
    });
  });

  group('SentryClient : apply scope to the captured event', () {
    SentryOptions options;
    String eventLevel;
    String eventTransaction;
    String eventBreadcrumbMessage;
    List<dynamic> eventFingerprint;
    String userId;
    Scope scope;
    String capturedScopeTagValue;
    String capturedScopeExtraValue;
    String capturedEventTagValue;
    String capturedEventExtraValue;

    final level = SentryLevel.error;
    final transaction = '/test/scope';
    final fingerprint = ['foo', 'bar', 'baz'];
    final user = User(id: '123', username: 'test');
    final crumb = Breadcrumb(message: 'bread');
    final scopeTagKey = 'scope-tag';
    final scopeTagValue = 'scope-tag-value';
    final eventTagKey = 'event-tag';
    final eventTagValue = 'event-tag-value';
    final scopeExtraKey = 'scope-extra';
    final scopeExtraValue = 'scope-extra-value';
    final eventExtraKey = 'event-extra';
    final eventExtraValue = 'event-extra-value';

    final event = SentryEvent(
      tags: {eventTagKey: eventTagValue},
      extra: {eventExtraKey: eventExtraValue},
      level: SentryLevel.warning,
    );

    final mockClient = MockClient((request) async {
      if (request.method == 'POST') {
        final body = const JsonDecoder().convert(
          Utf8Codec().decode(request.bodyBytes),
        );

        eventLevel = body['level'];
        eventTransaction = body['transaction'];
        eventFingerprint = body['fingerprint'];
        userId = body['user']['id'];
        eventBreadcrumbMessage = body['breadcrumbs']['values'].first['message'];
        capturedScopeTagValue = body['tags'][scopeTagKey];
        capturedEventTagValue = body['tags'][eventTagKey];
        capturedScopeExtraValue = body['extra'][scopeExtraKey];
        capturedEventExtraValue = body['extra'][eventExtraKey];

        return Response('{"id": "test-event-id"}', 200);
      }
      fail(
        'Unexpected request on ${request.method} ${request.url} in HttpMock',
      );
    });

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.compressPayload = false;
      options.httpClient = mockClient;
      scope = Scope(options)
        ..user = user
        ..level = level
        ..transaction = transaction
        ..fingerprint = fingerprint
        ..addBreadcrumb(crumb)
        ..setTag(scopeTagKey, scopeTagValue)
        ..setExtra(scopeExtraKey, scopeExtraValue);
    });

    test('should apply the scope', () async {
      final client = SentryClient(options);
      await client.captureEvent(event, scope: scope);

      expect(userId, '123');
      expect(eventLevel, 'error');
      expect(eventTransaction, transaction);
      expect(eventFingerprint, fingerprint);
      expect(eventBreadcrumbMessage, crumb.message);
      expect(capturedScopeTagValue, scopeTagValue);
      expect(capturedEventTagValue, eventTagValue);
      expect(capturedScopeExtraValue, scopeExtraValue);
      expect(capturedEventExtraValue, eventExtraValue);
    });
  });

  group('SentryClient sampling', () {
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('captures event, sample rate is 100% enabled', () {
      options.sampleRate = 1.0;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });

    test('do not capture event, sample rate is 0% disabled', () {
      options.sampleRate = 0.0;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verifyNever(options.transport.send(any));
    });

    test('captures event, sample rate is null, disabled', () {
      options.sampleRate = null;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });
  });

  group('SentryClient before send', () {
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('before send drops event', () {
      options.beforeSendCallback = beforeSendCallbackDropEvent;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verifyNever(options.transport.send(any));
    });

    test('before send returns an event and event is captured', () {
      options.beforeSendCallback = beforeSendCallback;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });
  });
}

SentryEvent beforeSendCallbackDropEvent(SentryEvent event, dynamic hint) =>
    null;

SentryEvent beforeSendCallback(SentryEvent event, dynamic hint) => event;
