/*
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

      expect(userId, user.id);
      expect(eventLevel, SentryLevel.error.name);
      expect(eventTransaction, transaction);
      expect(eventFingerprint, fingerprint);
      expect(eventBreadcrumbMessage, crumb.message);
      expect(capturedScopeTagValue, scopeTagValue);
      expect(capturedEventTagValue, eventTagValue);
      expect(capturedScopeExtraValue, scopeExtraValue);
      expect(capturedEventExtraValue, eventExtraValue);
    });
  });

  group('SentryClient : apply partial scope to the captured event', () {
    SentryOptions options;
    String capturedLevel;
    String capturedTransaction;
    String capturedBreadcrumbMessage;
    List<dynamic> capturedFingerprint;
    String capturedUserId;
    Scope scope;

    final transaction = '/test/scope';
    final eventTransaction = '/event/transaction';
    final fingerprint = ['foo', 'bar', 'baz'];
    final eventFingerprint = ['123', '456', '798'];
    final user = User(id: '123');
    final eventUser = User(id: '987');
    final crumb = Breadcrumb(message: 'bread');
    final eventCrumbs = [Breadcrumb(message: 'bread')];

    final event = SentryEvent(
      level: SentryLevel.warning,
      transaction: eventTransaction,
      userContext: eventUser,
      fingerprint: eventFingerprint,
      breadcrumbs: eventCrumbs,
    );

    final mockClient = MockClient((request) async {
      if (request.method == 'POST') {
        final body = const JsonDecoder().convert(
          Utf8Codec().decode(request.bodyBytes),
        );

        capturedLevel = body['level'];
        capturedTransaction = body['transaction'];
        capturedFingerprint = body['fingerprint'];
        capturedUserId = body['user']['id'];
        capturedBreadcrumbMessage =
            body['breadcrumbs']['values'].first['message'];

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
        ..transaction = transaction
        ..fingerprint = fingerprint
        ..addBreadcrumb(crumb);
    });

    test('should not apply the scope to non null event fields ', () async {
      final client = SentryClient(options);
      await client.captureEvent(event, scope: scope);

      expect(capturedUserId, eventUser.id);
      expect(capturedLevel, SentryLevel.warning.name);
      expect(capturedTransaction, eventTransaction);
      expect(capturedFingerprint, eventFingerprint);
      expect(capturedBreadcrumbMessage, eventCrumbs.first.message);
    });
  });
 */
