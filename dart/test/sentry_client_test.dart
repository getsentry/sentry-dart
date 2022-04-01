import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_transport.dart';

void main() {
  group('SentryClient captures message', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should capture event stacktrace', () async {
      final client = fixture.getSut(attachStacktrace: false);
      final event = SentryEvent();
      await client.captureEvent(
        event,
        stackTrace: '#0      baz (file:///pathto/test.dart:50:3)',
      );

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.threads?.first.stacktrace, isA<SentryStackTrace>());
    });

    test('should attach event stacktrace', () async {
      final client = fixture.getSut();
      final event = SentryEvent();
      await client.captureEvent(event);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.threads?.first.stacktrace, isA<SentryStackTrace>());
    });

    test('should not attach event stacktrace', () async {
      final client = fixture.getSut(attachStacktrace: false);
      final event = SentryEvent();
      await client.captureEvent(event);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.threads?.first.stacktrace, isNull);
    });

    test('should not attach event stacktrace if event has throwable', () async {
      final client = fixture.getSut();

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

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.threads?.first.stacktrace, isNull);
      expect(capturedEvent.exceptions?.first.stackTrace, isNotNull);
    });

    test('should not attach event stacktrace if event has exception', () async {
      final client = fixture.getSut();

      final exception = SentryException(
        type: 'Exception',
        value: 'an exception',
        stackTrace: SentryStackTrace(
          frames: SentryStackTraceFactory(fixture.options)
              .getStackFrames('#0      baz (file:///pathto/test.dart:50:3)'),
        ),
      );
      final event = SentryEvent(exceptions: [exception]);

      await client.captureEvent(
        event,
        stackTrace: '#0      baz (file:///pathto/test.dart:50:3)',
      );

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.threads?.first.stacktrace, isNull);
      expect(capturedEvent.exceptions?.first.stackTrace, isNotNull);
    });

    test('should capture message', () async {
      final client = fixture.getSut();
      await client.captureMessage(
        'simple message 1',
        template: 'simple message %d',
        params: [1],
        level: SentryLevel.error,
      );

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.message!.formatted, 'simple message 1');
      expect(capturedEvent.message!.template, 'simple message %d');
      expect(capturedEvent.message!.params, [1]);
      expect(capturedEvent.level, SentryLevel.error);
    });

    test('capture message defaults to info level', () async {
      final client = fixture.getSut();
      await client.captureMessage(
        'simple message 1',
      );

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.level, SentryLevel.info);
    });

    test('should capture message without stacktrace', () async {
      final client = fixture.getSut(attachStacktrace: false);
      await client.captureMessage('message', level: SentryLevel.error);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.threads?.first.stacktrace, isNull);
    });
  });

  group('SentryClient captures exception', () {
    Error error;
    StackTrace stackTrace;

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should capture error', () async {
      try {
        throw StateError('Error');
      } on Error catch (err, stack) {
        error = err;
        stackTrace = stack;
      }

      final client = fixture.getSut();
      await client.captureException(error, stackTrace: stackTrace);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?.first is SentryException, true);
      expect(capturedEvent.exceptions?.first.stackTrace, isNotNull);
    });
  });

  group('SentryClient captures exception and stacktrace', () {
    late Fixture fixture;

    Error error;

    final stacktrace = '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''';

    setUp(() {
      fixture = Fixture();
    });

    test('should capture error', () async {
      try {
        throw StateError('Error');
      } on Error catch (err) {
        error = err;
      }

      final client = fixture.getSut();
      await client.captureException(error, stackTrace: stacktrace);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?.first is SentryException, true);
      expect(capturedEvent.exceptions?.first.stackTrace, isNotNull);
      expect(capturedEvent.exceptions?.first.stackTrace!.frames.first.fileName,
          'test.dart');
      expect(
          capturedEvent.exceptions?.first.stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exceptions?.first.stackTrace!.frames.first.colNo, 9);
    });
  });

  group('SentryClient captures exception and stacktrace', () {
    late Fixture fixture;

    dynamic exception;

    setUp(() {
      fixture = Fixture();
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

      final client = fixture.getSut();
      await client.captureException(exception, stackTrace: stacktrace);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?.first is SentryException, true);
      expect(capturedEvent.exceptions?.first.stackTrace!.frames.first.fileName,
          'test.dart');
      expect(
          capturedEvent.exceptions?.first.stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exceptions?.first.stackTrace!.frames.first.colNo, 9);
    });

    test('should capture exception with Stackframe.current', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final client = fixture.getSut();
      await client.captureException(exception);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?.first.stackTrace, isNotNull);
    });

    test('should capture exception without Stackframe.current', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final client = fixture.getSut(attachStacktrace: false);
      await client.captureException(exception);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?.first.stackTrace, isNull);
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

      final client = fixture.getSut();
      await client.captureException(exception, stackTrace: stacktrace);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(
        capturedEvent.exceptions?.first.stackTrace!.frames
            .every((frame) => frame.package != 'sentry'),
        true,
      );
    });
  });

  group('SentryClient captures transaction', () {
    late Fixture fixture;

    Error error;

    setUp(() {
      fixture = Fixture();
    });

    test('should contain a transaction in the envelope', () async {
      try {
        throw StateError('Error');
      } on Error catch (err) {
        error = err;
      }

      final client = fixture.getSut();
      final tr = SentryTransaction(fixture.tracer, throwable: error);
      await client.captureTransaction(tr);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedTr = await transactionFromEnvelope(capturedEnvelope);

      expect(capturedTr['type'], 'transaction');
    });

    test('should not set exception to transactions', () async {
      try {
        throw StateError('Error');
      } on Error catch (err) {
        error = err;
      }

      final client = fixture.getSut();
      final tr = SentryTransaction(fixture.tracer, throwable: error);
      await client.captureTransaction(tr);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await transactionFromEnvelope(capturedEnvelope);

      expect(capturedEvent['exception'], isNull);
    });

    test('attachments not added to captured transaction per default', () async {
      final attachment = SentryAttachment.fromUint8List(
        Uint8List.fromList([0, 0, 0, 0]),
        'test.txt',
      );
      final scope = Scope(fixture.options);
      scope.addAttachment(attachment);

      final client = fixture.getSut();
      final tr = SentryTransaction(fixture.tracer);
      await client.captureTransaction(tr, scope: scope);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedAttachments = capturedEnvelope.items
          .where((item) => item.header.type == SentryItemType.attachment);

      expect(capturedAttachments.isEmpty, true);
    });

    test('attachments added to captured event', () async {
      final attachment = SentryAttachment.fromUint8List(
        Uint8List.fromList([0, 0, 0, 0]),
        'test.txt',
        addToTransactions: true,
      );
      final scope = Scope(fixture.options);
      scope.addAttachment(attachment);

      final client = fixture.getSut();
      final tr = SentryTransaction(fixture.tracer);
      await client.captureTransaction(tr, scope: scope);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedAttachments = capturedEnvelope.items
          .where((item) => item.header.type == SentryItemType.attachment);

      expect(capturedAttachments.isNotEmpty, true);
    });

    test('attachments added to captured event per default', () async {
      final attachment = SentryAttachment.fromUint8List(
        Uint8List.fromList([0, 0, 0, 0]),
        'test.txt',
      );
      final scope = Scope(fixture.options);
      scope.addAttachment(attachment);

      final client = fixture.getSut();
      final event = SentryEvent();
      await client.captureEvent(event, scope: scope);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedAttachments = capturedEnvelope.items
          .where((item) => item.header.type == SentryItemType.attachment);

      expect(capturedAttachments.isNotEmpty, true);
    });

    test('should return empty for when transaction is discarded', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());
      final tr = SentryTransaction(fixture.tracer);
      final id = await client.captureTransaction(tr);

      expect(id, SentryId.empty());
    });
  });

  group('SentryClient : apply scope to the captured event', () {
    late Scope scope;

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

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      scope = Scope(fixture.options)
        ..user = user
        ..level = level
        ..transaction = transaction
        ..fingerprint = fingerprint
        ..addBreadcrumb(crumb)
        ..setTag(scopeTagKey, scopeTagValue)
        ..setExtra(scopeExtraKey, scopeExtraValue);
    });

    test('should apply the scope', () async {
      final client = fixture.getSut();
      await client.captureEvent(event, scope: scope);

      final capturedEnvelope = (fixture.transport).envelopes.first;
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
    late Fixture fixture;

    final transaction = '/test/scope';
    final eventTransaction = '/event/transaction';
    final fingerprint = ['foo', 'bar', 'baz'];
    final eventFingerprint = ['123', '456', '798'];
    final user = SentryUser(id: '123');
    final crumb = Breadcrumb(message: 'bread');
    final eventUser = SentryUser(id: '987');
    final eventCrumbs = [Breadcrumb(message: 'bread')];

    final event = SentryEvent(
      level: SentryLevel.warning,
      transaction: eventTransaction,
      user: eventUser,
      fingerprint: eventFingerprint,
      breadcrumbs: eventCrumbs,
    );

    Scope createScope(SentryOptions options) {
      return Scope(options)
        ..user = user
        ..transaction = transaction
        ..fingerprint = fingerprint
        ..addBreadcrumb(crumb);
    }

    setUp(() {
      fixture = Fixture();
    });

    test('should not apply the scope to non null event fields ', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final scope = createScope(fixture.options);

      await client.captureEvent(event, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user!.id, eventUser.id);
      expect(capturedEvent.level!.name, SentryLevel.warning.name);
      expect(capturedEvent.transaction, eventTransaction);
      expect(capturedEvent.fingerprint, eventFingerprint);
      expect(capturedEvent.breadcrumbs?.map((e) => e.toJson()),
          eventCrumbs.map((e) => e.toJson()));
    });

    test('should apply the scope user to null event user fields ', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final scope = createScope(fixture.options);

      scope.user = SentryUser(id: '987');

      var eventWithUser = event.copyWith(
        user: SentryUser(id: '123', username: 'foo bar'),
      );
      await client.captureEvent(eventWithUser, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user!.id, '123');
      expect(capturedEvent.user!.username, 'foo bar');
      expect(capturedEvent.level!.name, SentryLevel.warning.name);
      expect(capturedEvent.transaction, eventTransaction);
      expect(capturedEvent.fingerprint, eventFingerprint);
      expect(capturedEvent.breadcrumbs?.map((e) => e.toJson()),
          eventCrumbs.map((e) => e.toJson()));
    });

    test('merge scope user and event user extra', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final scope = createScope(fixture.options);

      scope.user = SentryUser(
        id: 'id',
        extras: {
          'foo': 'bar',
          'bar': 'foo',
        },
      );

      var eventWithUser = event.copyWith(
        user: SentryUser(
          id: 'id',
          extras: {
            'foo': 'this bar is more important',
            'event': 'Really important event'
          },
        ),
      );
      await client.captureEvent(eventWithUser, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.extras?['foo'], 'this bar is more important');
      expect(capturedEvent.user?.extras?['bar'], 'foo');
      expect(capturedEvent.user?.extras?['event'], 'Really important event');
    });
  });

  group('SentryClient: apply default pii', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('sendDefaultPii is disabled', () async {
      final client = fixture.getSut(sendDefaultPii: false);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.toJson(), fakeEvent.user?.toJson());
    });

    test('sendDefaultPii is enabled and event has no user', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      var fakeEvent = SentryEvent();

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, '{{auto}}');
    });

    test('sendDefaultPii is enabled and event has a user with IP address',
        () async {
      final client = fixture.getSut(sendDefaultPii: true);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      // fakeEvent has a user which is not null
      expect(capturedEvent.user?.ipAddress, fakeEvent.user!.ipAddress);
      expect(capturedEvent.user?.id, fakeEvent.user!.id);
      expect(capturedEvent.user?.email, fakeEvent.user!.email);
    });

    test('sendDefaultPii is enabled and event has a user without IP address',
        () async {
      final client = fixture.getSut(sendDefaultPii: true);

      final event = fakeEvent.copyWith(user: fakeUser);

      await client.captureEvent(event);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, '{{auto}}');
      expect(capturedEvent.user?.id, fakeUser.id);
      expect(capturedEvent.user?.email, fakeUser.email);
    });
  });

  group('SentryClient sampling', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('captures event, sample rate is 100% enabled', () async {
      final client = fixture.getSut(sampleRate: 1.0);
      await client.captureEvent(fakeEvent);

      expect((fixture.transport).called(1), true);
    });

    test('do not capture event, sample rate is 0% disabled', () async {
      final client = fixture.getSut(sampleRate: 0.0);
      await client.captureEvent(fakeEvent);

      expect((fixture.transport).called(0), true);
    });

    test('captures event, sample rate is null, disabled', () async {
      final client = fixture.getSut();
      await client.captureEvent(fakeEvent);

      expect((fixture.transport).called(1), true);
    });
  });

  group('SentryClient before send', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('before send drops event', () async {
      final client = fixture.getSut(beforeSend: beforeSendCallbackDropEvent);
      await client.captureEvent(fakeEvent);

      expect((fixture.transport).called(0), true);
    });

    test('async before send drops event', () async {
      final client =
          fixture.getSut(beforeSend: asyncBeforeSendCallbackDropEvent);
      await client.captureEvent(fakeEvent);

      expect((fixture.transport).called(0), true);
    });

    test('before send returns an event and event is captured', () async {
      final client = fixture.getSut(beforeSend: beforeSendCallback);
      await client.captureEvent(fakeEvent);

      final capturedEnvelope = (fixture.transport).envelopes.first;
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
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      fixture.options.addEventProcessor(FunctionEventProcessor(
        (event, {hint}) => event
          ..tags!.addAll({'theme': 'material'})
          ..extra!['host'] = '0.0.0.1'
          ..modules!.addAll({'core': '1.0'})
          ..breadcrumbs!.add(Breadcrumb(message: 'processor crumb'))
          ..fingerprint!.add('process')
          ..sdk!.addIntegration('testIntegration')
          ..sdk!.addPackage('test-pkg', '1.0'),
      ));
    });

    test('should execute eventProcessors', () async {
      final client = fixture.getSut();
      await client.captureEvent(fakeEvent);

      final capturedEnvelope = (fixture.transport).envelopes.first;
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

      final client = fixture.getSut(
          eventProcessor: FunctionEventProcessor((event, {hint}) {
        expect(myHint, hint);
        executed = true;
        return event;
      }));

      await client.captureEvent(fakeEvent, hint: myHint);

      expect(executed, true);
    });

    test('event processor drops the event', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());
      await client.captureEvent(fakeEvent);

      expect((fixture.transport).called(0), true);
    });
  });

  group('SentryClient captures envelope', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should capture envelope', () async {
      final client = fixture.getSut();
      await client.captureEnvelope(fakeEnvelope);

      final capturedEnvelope = (fixture.transport).envelopes.first;

      expect(capturedEnvelope, fakeEnvelope);
    });
  });
}

Future<SentryEvent> eventFromEnvelope(SentryEnvelope envelope) async {
  final envelopeItemData = <int>[];
  envelopeItemData.addAll(await envelope.items.first.envelopeItemStream());

  final envelopeItem = utf8.decode(envelopeItemData);
  final envelopeItemJson = jsonDecode(envelopeItem.split('\n').last);
  return SentryEvent.fromJson(envelopeItemJson as Map<String, dynamic>);
}

Future<Map<String, dynamic>> transactionFromEnvelope(
    SentryEnvelope envelope) async {
  final envelopeItemData = <int>[];
  envelopeItemData.addAll(await envelope.items.first.envelopeItemStream());

  final envelopeItem = utf8.decode(envelopeItemData);
  final envelopeItemJson = jsonDecode(envelopeItem.split('\n').last);
  return envelopeItemJson as Map<String, dynamic>;
}

FutureOr<SentryEvent?> beforeSendCallbackDropEvent(
  SentryEvent event, {
  dynamic hint,
}) =>
    null;

FutureOr<SentryEvent?> asyncBeforeSendCallbackDropEvent(
  SentryEvent event, {
  dynamic hint,
}) async {
  await Future.delayed(Duration(milliseconds: 200));
  return null;
}

FutureOr<SentryEvent?> beforeSendCallback(SentryEvent event, {dynamic hint}) {
  return event
    ..tags!.addAll({'theme': 'material'})
    ..extra!['host'] = '0.0.0.1'
    ..modules!.addAll({'core': '1.0'})
    ..breadcrumbs!.add(Breadcrumb(message: 'processor crumb'))
    ..fingerprint!.add('process')
    ..sdk!.addIntegration('testIntegration')
    ..sdk!.addPackage('test-pkg', '1.0');
}

class Fixture {
  final transport = MockTransport();

  final options = SentryOptions(dsn: fakeDsn);
  late SentryTransactionContext _context;
  late SentryTracer tracer;

  SentryClient getSut({
    bool sendDefaultPii = false,
    bool attachStacktrace = true,
    double? sampleRate,
    BeforeSendCallback? beforeSend,
    EventProcessor? eventProcessor,
  }) {
    final hub = Hub(options);
    _context = SentryTransactionContext(
      'name',
      'op',
    );
    tracer = SentryTracer(_context, hub);

    options.tracesSampleRate = 1.0;
    options.sendDefaultPii = sendDefaultPii;
    options.attachStacktrace = attachStacktrace;
    options.sampleRate = sampleRate;
    options.beforeSend = beforeSend;
    if (eventProcessor != null) {
      options.addEventProcessor(eventProcessor);
    }
    options.transport = transport;
    final client = SentryClient(options);
    // hub.bindClient(client);

    return client;
  }
}
