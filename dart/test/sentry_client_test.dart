import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('SentryClient captures message', () {
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture message', () async {
      final client = SentryClient(options);
      await client.captureMessage(
        'simple message 1',
        template: 'simple message %d',
        params: [1],
        level: SentryLevel.error,
      );

      final capturedEvent = (verify(
        options.transport.send(captureAny),
      ).captured.first) as SentryEvent;

      expect(capturedEvent.message.formatted, 'simple message 1');
      expect(capturedEvent.message.template, 'simple message %d');
      expect(capturedEvent.message.params, [1]);
    });
  });

  group('SentryClient captures exception', () {
    SentryOptions options;

    Error error;
    StackTrace stackTrace;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture exception', () async {
      try {
        throw StateError('Error');
      } on Error catch (err, stack) {
        error = err;
        stackTrace = stack;
      }

      final client = SentryClient(options);
      await client.captureException(error, stackTrace: stackTrace);

      final capturedEvent = (verify(
        options.transport.send(captureAny),
      ).captured.first) as SentryEvent;

      expect(capturedEvent.exception, error);
      expect(capturedEvent.stackTrace, stackTrace);
    });
  });

  group('SentryClient : apply scope to the captured event', () {
    SentryOptions options;
    Scope scope;

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

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();

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

      final capturedEvent = (verify(
        options.transport.send(captureAny),
      ).captured.first) as SentryEvent;

      expect(capturedEvent.user?.id, user.id);
      expect(capturedEvent.level.name, SentryLevel.error.name);
      expect(capturedEvent.transaction, transaction);
      expect(capturedEvent.fingerprint, fingerprint);
      expect(capturedEvent.breadcrumbs.first, crumb);
      expect(capturedEvent.tags, {
        scopeTagKey: scopeTagValue,
        eventTagKey: eventTagValue,
      });
      expect(capturedEvent.extra, {
        scopeExtraKey: scopeExtraValue,
        eventExtraKey: eventExtraValue,
      });
    });
  });

  group('SentryClient : apply partial scope to the captured event', () {
    SentryOptions options;
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
      user: eventUser,
      fingerprint: eventFingerprint,
      breadcrumbs: eventCrumbs,
    );

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
      scope = Scope(options)
        ..user = user
        ..transaction = transaction
        ..fingerprint = fingerprint
        ..addBreadcrumb(crumb);
    });

    test('should not apply the scope to non null event fields ', () async {
      final client = SentryClient(options);
      await client.captureEvent(event, scope: scope);

      final capturedEvent = (verify(
        options.transport.send(captureAny),
      ).captured.first) as SentryEvent;

      expect(capturedEvent.user.id, eventUser.id);
      expect(capturedEvent.level.name, SentryLevel.warning.name);
      expect(capturedEvent.transaction, eventTransaction);
      expect(capturedEvent.fingerprint, eventFingerprint);
      expect(capturedEvent.breadcrumbs, eventCrumbs);
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
      options.beforeSend = beforeSendCallbackDropEvent;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verifyNever(options.transport.send(any));
    });

    test('before send returns an event and event is captured', () {
      options.beforeSend = beforeSendCallback;
      final client = SentryClient(options);
      client.captureEvent(fakeEvent);

      verify(options.transport.send(any)).called(1);
    });
  });
}

SentryEvent beforeSendCallbackDropEvent(SentryEvent event, dynamic hint) =>
    null;

SentryEvent beforeSendCallback(SentryEvent event, dynamic hint) => event;
