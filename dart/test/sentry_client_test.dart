import 'dart:convert';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_transport.dart';

void main() {
  group('SentryClient captures message', () {
    var options = SentryOptions(dsn: fakeDsn);

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture event stacktrace', () async {
      final client = SentryClient(options..attachStacktrace = false);
      final event = SentryEvent();
      await client.captureEvent(
        event,
        stackTrace: '#0      baz (file:///pathto/test.dart:50:3)',
      );

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.stackTrace is SentryStackTrace, true);
    });

    test('should attach event stacktrace', () async {
      final client = SentryClient(options);
      final event = SentryEvent();
      await client.captureEvent(event);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.stackTrace is SentryStackTrace, true);
    });

    test('should not attach event stacktrace', () async {
      final client = SentryClient(options..attachStacktrace = false);
      final event = SentryEvent();
      await client.captureEvent(event);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.stackTrace, isNull);
    });

    test('should not attach event stacktrace if event has throwable', () async {
      final client = SentryClient(options);

      SentryEvent event;
      try {
        throw StateError('Error');
      } on Error catch (err) {
        event = SentryEvent(throwable: err);
      }

      await client.captureEvent(
        event,
        stackTrace: '#0      baz (file:///pathto/test.dart:50:3)',
      );

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.stackTrace, isNull);
      expect(capturedEvent.exception!.stackTrace, isNotNull);
    });

    test('should not attach event stacktrace if event has exception', () async {
      final client = SentryClient(options);

      final exception = SentryException(
        type: 'Exception',
        value: 'an exception',
        stackTrace: SentryStackTrace(
          frames: SentryStackTraceFactory(options)
              .getStackFrames('#0      baz (file:///pathto/test.dart:50:3)'),
        ),
      );
      final event = SentryEvent(exception: exception);

      await client.captureEvent(
        event,
        stackTrace: '#0      baz (file:///pathto/test.dart:50:3)',
      );

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.stackTrace, isNull);
      expect(capturedEvent.exception!.stackTrace, isNotNull);
    });

    test('should capture message', () async {
      final client = SentryClient(options);
      await client.captureMessage(
        'simple message 1',
        template: 'simple message %d',
        params: [1],
        level: SentryLevel.error,
      );

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.message!.formatted, 'simple message 1');
      expect(capturedEvent.message!.template, 'simple message %d');
      expect(capturedEvent.message!.params, [1]);
      expect(capturedEvent.level, SentryLevel.error);
    });

    test('capture message defaults to info level', () async {
      final client = SentryClient(options);
      await client.captureMessage(
        'simple message 1',
      );

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.level, SentryLevel.info);
    });

    test('should capture message without stacktrace', () async {
      final client = SentryClient(options..attachStacktrace = false);
      await client.captureMessage('message', level: SentryLevel.error);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.stackTrace, isNull);
    });
  });

  group('SentryClient captures exception', () {
    var options = SentryOptions(dsn: fakeDsn);

    Error error;
    final stackTrace = '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''';

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture error', () async {
      try {
        throw StateError('Error');
      } on Error catch (err) {
        error = err;
      }

      final client = SentryClient(options);
      await client.captureException(error, stackTrace: stackTrace);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exception is SentryException, true);
      expect(capturedEvent.exception!.stackTrace, isNotNull);
      expect(capturedEvent.exception!.stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exception!.stackTrace!.frames.first.colNo, 9);
    });
  });

  group('SentryClient captures exception and stacktrace', () {
    var options = SentryOptions(dsn: fakeDsn);

    Error error;

    final stacktrace = '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''';

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture error', () async {
      try {
        throw StateError('Error');
      } on Error catch (err) {
        error = err;
      }

      final client = SentryClient(options);
      await client.captureException(error, stackTrace: stacktrace);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exception is SentryException, true);
      expect(capturedEvent.exception!.stackTrace, isNotNull);
      expect(capturedEvent.exception!.stackTrace!.frames.first.fileName,
          'test.dart');
      expect(capturedEvent.exception!.stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exception!.stackTrace!.frames.first.colNo, 9);
    });
  });

  group('SentryClient captures exception and stacktrace', () {
    var options = SentryOptions(dsn: fakeDsn);

    dynamic exception;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture exception', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final stacktrace = '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''';

      final client = SentryClient(options);
      await client.captureException(exception, stackTrace: stacktrace);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exception is SentryException, true);
      expect(capturedEvent.exception!.stackTrace!.frames.first.fileName,
          'test.dart');
      expect(capturedEvent.exception!.stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exception!.stackTrace!.frames.first.colNo, 9);
    });

    test('should capture exception with Stackframe.current', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final client = SentryClient(options);
      await client.captureException(exception);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exception!.stackTrace, isNotNull);
    });

    test('should capture exception without Stackframe.current', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final client = SentryClient(options..attachStacktrace = false);
      await client.captureException(exception);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exception!.stackTrace, isNull);
    });

    test('should not capture sentry frames exception', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final stacktrace = '''
#0      init (package:sentry/sentry.dart:46:9)
#1      bar (file:///pathto/test.dart:46:9)
<asynchronous suspension>
#2      capture (package:sentry/sentry.dart:46:9)
      ''';

      final client = SentryClient(options);
      await client.captureException(exception, stackTrace: stacktrace);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(
        capturedEvent.exception!.stackTrace!.frames
            .every((frame) => frame.package != 'sentry'),
        true,
      );
    });
  });

  group('SentryClient : apply scope to the captured event', () {
    var options = SentryOptions(dsn: fakeDsn);
    var scope = Scope(options);

    final level = SentryLevel.error;
    const transaction = '/test/scope';
    const fingerprint = ['foo', 'bar', 'baz'];
    final user = SentryUser(id: '123', username: 'test');
    final crumb = Breadcrumb(message: 'bread');
    const scopeTagKey = 'scope-tag';
    const scopeTagValue = 'scope-tag-value';
    const eventTagKey = 'event-tag';
    const eventTagValue = 'event-tag-value';
    const scopeExtraKey = 'scope-extra';
    const scopeExtraValue = 'scope-extra-value';
    const eventExtraKey = 'event-extra';
    const eventExtraValue = 'event-extra-value';

    final event = SentryEvent(
      tags: const {eventTagKey: eventTagValue},
      extra: const {eventExtraKey: eventExtraValue},
      modules: const {eventExtraKey: eventExtraValue},
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

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.id, user.id);
      expect(capturedEvent.level!.name, SentryLevel.error.name);
      expect(capturedEvent.transaction, transaction);
      expect(capturedEvent.fingerprint, fingerprint);
      expect(capturedEvent.breadcrumbs?.first.toJson(), crumb.toJson());
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
    var options = SentryOptions(dsn: fakeDsn);
    var scope = Scope(options);

    final transaction = '/test/scope';
    final eventTransaction = '/event/transaction';
    const fingerprint = ['foo', 'bar', 'baz'];
    const eventFingerprint = ['123', '456', '798'];
    final user = SentryUser(id: '123');
    final eventUser = SentryUser(id: '987');
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

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user!.id, eventUser.id);
      expect(capturedEvent.level!.name, SentryLevel.warning.name);
      expect(capturedEvent.transaction, eventTransaction);
      expect(capturedEvent.fingerprint, eventFingerprint);
      expect(capturedEvent.breadcrumbs?.map((e) => e.toJson()),
          eventCrumbs.map((e) => e.toJson()));
    });
  });

  group('SentryClient: apply default pii', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('sendDefaultPii is disabled', () async {
      final transport = MockTransport();
      final client = fixture.getSut(false, transport);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.toJson(), fakeEvent.user?.toJson());
    });

    test('sendDefaultPii is enabled and event has no user', () async {
      final transport = MockTransport();
      final client = fixture.getSut(true, transport);
      var fakeEvent = SentryEvent();

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, '{{auto}}');
    });

    test('sendDefaultPii is enabled and event has a user with IP address',
        () async {
      final transport = MockTransport();
      final client = fixture.getSut(true, transport);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      // fakeEvent has a user which is not null
      expect(capturedEvent.user?.ipAddress, fakeEvent.user!.ipAddress);
      expect(capturedEvent.user?.id, fakeEvent.user!.id);
      expect(capturedEvent.user?.email, fakeEvent.user!.email);
    });

    test('sendDefaultPii is enabled and event has a user without IP address',
        () async {
      final transport = MockTransport();
      final client = fixture.getSut(true, transport);

      final event = fakeEvent.copyWith(user: fakeUser);

      await client.captureEvent(event);

      final capturedEnvelope = transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, '{{auto}}');
      expect(capturedEvent.user?.id, fakeUser.id);
      expect(capturedEvent.user?.email, fakeUser.email);
    });
  });

  group('SentryClient sampling', () {
    var options = SentryOptions(dsn: fakeDsn);

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('captures event, sample rate is 100% enabled', () async {
      options.sampleRate = 1.0;
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      expect((options.transport as MockTransport).called(1), true);
    });

    test('do not capture event, sample rate is 0% disabled', () async {
      options.sampleRate = 0.0;
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      expect((options.transport as MockTransport).called(0), true);
    });

    test('captures event, sample rate is null, disabled', () async {
      options.sampleRate = null;
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      expect((options.transport as MockTransport).called(1), true);
    });
  });

  group('SentryClient before send', () {
    var options = SentryOptions(dsn: fakeDsn);

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('before send drops event', () async {
      options.beforeSend = beforeSendCallbackDropEvent;
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      expect((options.transport as MockTransport).called(0), true);
    });

    test('before send returns an event and event is captured', () async {
      options.beforeSend = beforeSendCallback;
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final event = await eventFromEnvelope(capturedEnvelope);

      expect(event.tags!.containsKey('theme'), true);
      expect(event.extra!.containsKey('host'), true);
      expect(event.modules!.containsKey('core'), true);
      expect(event.sdk!.integrations.contains('testIntegration'), true);
      expect(
        event.sdk!.packages.any((element) => element.name == 'test-pkg'),
        true,
      );
      expect(
        event.breadcrumbs!
            .any((element) => element.message == 'processor crumb'),
        true,
      );
      expect(event.fingerprint!.contains('process'), true);
    });
  });

  group('EventProcessors', () {
    var options = SentryOptions(dsn: fakeDsn);

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.addEventProcessor(
        (event, {hint}) => event
          ..tags!.addAll({'theme': 'material'})
          ..extra!['host'] = '0.0.0.1'
          ..modules!.addAll({'core': '1.0'})
          ..breadcrumbs!.add(Breadcrumb(message: 'processor crumb'))
          ..fingerprint!.add('process')
          ..sdk!.addIntegration('testIntegration')
          ..sdk!.addPackage('test-pkg', '1.0'),
      );
      options.transport = MockTransport();
    });

    test('should execute eventProcessors', () async {
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;
      final event = await eventFromEnvelope(capturedEnvelope);

      expect(event.tags!.containsKey('theme'), true);
      expect(event.extra!.containsKey('host'), true);
      expect(event.modules!.containsKey('core'), true);
      expect(event.sdk!.integrations.contains('testIntegration'), true);
      expect(
        event.sdk!.packages.any((element) => element.name == 'test-pkg'),
        true,
      );
      expect(
        event.breadcrumbs!
            .any((element) => element.message == 'processor crumb'),
        true,
      );
      expect(event.fingerprint!.contains('process'), true);
    });

    test('should pass hint to eventProcessors', () async {
      final myHint = 'hint';
      var executed = false;

      options.addEventProcessor((event, {hint}) {
        expect(myHint, hint);
        executed = true;
        return event;
      });
      final client = SentryClient(options);

      await client.captureEvent(fakeEvent, hint: myHint);

      expect(executed, true);
    });

    test('event processor drops the event', () async {
      options.addEventProcessor(eventProcessorDropEvent);
      final client = SentryClient(options);
      await client.captureEvent(fakeEvent);

      expect((options.transport as MockTransport).called(0), true);
    });
  });

  group('SentryClient captures envelope', () {
    var options = SentryOptions(dsn: fakeDsn);

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      options.transport = MockTransport();
    });

    test('should capture envelope', () async {
      final client = SentryClient(options);
      await client.captureEnvelope(fakeEnvelope);

      final capturedEnvelope =
          (options.transport as MockTransport).envelopes.first;

      expect(capturedEnvelope, fakeEnvelope);
    });
  });
}

Future<SentryEvent> eventFromEnvelope(SentryEnvelope envelope) async {
  final envelopeItemData = <int>[];
  await envelope.items.first
      .envelopeItemStream()
      .forEach(envelopeItemData.addAll);
  final envelopeItem = utf8.decode(envelopeItemData);
  final envelopeItemJson = jsonDecode(envelopeItem.split('\n').last);
  return SentryEvent.fromJson(envelopeItemJson as Map<String, dynamic>);
}

SentryEvent? beforeSendCallbackDropEvent(SentryEvent event, {dynamic hint}) =>
    null;

SentryEvent beforeSendCallback(SentryEvent event, {dynamic hint}) {
  return event
    ..tags!.addAll({'theme': 'material'})
    ..extra!['host'] = '0.0.0.1'
    ..modules!.addAll({'core': '1.0'})
    ..breadcrumbs!.add(Breadcrumb(message: 'processor crumb'))
    ..fingerprint!.add('process')
    ..sdk!.addIntegration('testIntegration')
    ..sdk!.addPackage('test-pkg', '1.0');
}

SentryEvent? eventProcessorDropEvent(SentryEvent event, {dynamic hint}) {
  return null;
}

class Fixture {
  /// Test Fixture for tests with [SentryOptions.sendDefaultPii]
  SentryClient getSut(bool sendDefaultPii, Transport transport) {
    var options = SentryOptions(dsn: fakeDsn);
    options.sendDefaultPii = sendDefaultPii;
    options.transport = transport;
    return SentryClient(options);
  }
}
