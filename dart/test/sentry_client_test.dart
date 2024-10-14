import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/client_report.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/discarded_event.dart';
import 'package:sentry/src/client_reports/noop_client_report_recorder.dart';
import 'package:sentry/src/metrics/metric.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:sentry/src/transport/spotlight_http_transport.dart';
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_envelope.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_platform.dart';
import 'mocks/mock_platform_checker.dart';
import 'mocks/mock_transport.dart';
import 'test_utils.dart';

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
        stackTrace: SentryStackTraceFactory(fixture.options)
            .parse('#0      baz (file:///pathto/test.dart:50:3)'),
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

    test(
      'should attach isolate info in thread',
      () async {
        final client = fixture.getSut(attachThreads: true);

        await client.captureException(
          Exception(),
          stackTrace: StackTrace.current,
        );

        final capturedEnvelope = (fixture.transport).envelopes.first;
        final capturedEvent = await eventFromEnvelope(capturedEnvelope);

        expect(capturedEvent.threads?.first.current, true);
        expect(capturedEvent.threads?.first.crashed, true);
        expect(capturedEvent.threads?.first.name, isNotNull);
        expect(capturedEvent.threads?.first.id, isNotNull);

        expect(
          capturedEvent.exceptions?.first.threadId,
          capturedEvent.threads?.first.id,
        );
      },
      onPlatform: {
        'js': Skip("Isolates don't exist on the web"),
        'wasm': Skip("Isolates don't exist on the web")
      },
    );

    test(
      'should not attach isolate info in thread if disabled',
      () async {
        final client = fixture.getSut(attachThreads: false);

        await client.captureException(
          Exception(),
          stackTrace: StackTrace.current,
        );

        final capturedEnvelope = (fixture.transport).envelopes.first;
        final capturedEvent = await eventFromEnvelope(capturedEnvelope);

        expect(capturedEvent.threads, null);
      },
      onPlatform: {'js': Skip("Isolates don't exist on the web")},
    );

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

    test('event envelope contains dsn', () async {
      final client = fixture.getSut();
      final event = SentryEvent();
      await client.captureEvent(event);

      final capturedEnvelope = (fixture.transport).envelopes.first;

      expect(capturedEnvelope.header.dsn, fixture.options.dsn);
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

  group('SentryClient captures exception cause', () {
    dynamic exception;

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should capture exception cause', () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      exception = ExceptionWithCause(cause, null);

      final client = fixture.getSut();
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[0] is SentryException, true);
      expect(capturedEvent.exceptions?[1] is SentryException, true);
    });

    test('should capture cause stacktrace', () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      final stackTrace = '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''';

      exception = ExceptionWithCause(cause, stackTrace);

      final client = fixture.getSut(attachStacktrace: true);
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[1].stackTrace, isNotNull);
      expect(capturedEvent.exceptions?[1].stackTrace!.frames.first.fileName,
          'test.dart');
      expect(capturedEvent.exceptions?[1].stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exceptions?[1].stackTrace!.frames.first.colNo, 9);
    });

    test('should capture custom stacktrace', () async {
      fixture.options.addExceptionStackTraceExtractor(
        ExceptionWithStackTraceExtractor(),
      );

      final stackTrace = StackTrace.fromString('''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
      ''');

      exception = ExceptionWithStackTrace(stackTrace);

      final client = fixture.getSut(attachStacktrace: true);
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[0].stackTrace, isNotNull);
      expect(capturedEvent.exceptions?[0].stackTrace!.frames.first.fileName,
          'test.dart');
      expect(capturedEvent.exceptions?[0].stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exceptions?[0].stackTrace!.frames.first.colNo, 9);
    });

    test('should not capture cause stacktrace when attachStacktrace is false',
        () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      exception = ExceptionWithCause(cause, null);

      final client = fixture.getSut(attachStacktrace: false);
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[1].stackTrace, isNull);
    });

    test(
        'should not capture cause stacktrace when attachStacktrace is false and StackTrace.empty',
        () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      exception = ExceptionWithCause(cause, StackTrace.empty);

      final client = fixture.getSut(attachStacktrace: false);
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[1].stackTrace, isNull);
    });

    test('should capture cause exception with Stackframe.current', () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      exception = ExceptionWithCause(cause, null);

      final client = fixture.getSut(attachStacktrace: true);
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[1].stackTrace, isNotNull);
    });

    test('should capture sentry frames exception', () async {
      fixture.options.removeStackFrameExclude('sentry');
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      final stackTrace = '''
#0      init (package:sentry/sentry.dart:46:9)
#1      bar (file:///pathto/test.dart:46:9)
<asynchronous suspension>
#2      capture (package:sentry/sentry.dart:46:9)
      ''';
      exception = ExceptionWithCause(cause, stackTrace);

      final client = fixture.getSut(attachStacktrace: true);
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      final sentryFramesCount = capturedEvent.exceptions?[1].stackTrace!.frames
          .where((frame) => frame.package == 'sentry')
          .length;

      expect(sentryFramesCount, 2);
    });
  });

  group('SentryClient captures exception and stacktrace', () {
    late Fixture fixture;

    Error error;

    dynamic exception;

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

    test('should capture exception', () async {
      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

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

    test('should capture sentry frames exception', () async {
      fixture.options.removeStackFrameExclude('sentry');

      try {
        throw Exception('Error');
      } catch (err) {
        exception = err;
      }

      final stackTrace = '''
#0      baz (file:///pathto/test.dart:50:3)
<asynchronous suspension>
#1      bar (file:///pathto/test.dart:46:9)
#2      capture (package:sentry/sentry.dart:46:9)
      ''';

      final client = fixture.getSut();
      await client.captureException(exception, stackTrace: stackTrace);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(
        capturedEvent.exceptions?.first.stackTrace!.frames
            .any((frame) => frame.package == 'sentry'),
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

    test(
        'when scope does not have an active transaction, trace state is set on the envelope from scope',
        () async {
      final client = fixture.getSut();
      final scope = Scope(fixture.options);
      await client.captureEvent(SentryEvent(), scope: scope);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedTraceContext = capturedEnvelope.header.traceContext;
      final capturedTraceId = capturedTraceContext?.traceId;
      final propagationContextTraceId = scope.propagationContext.traceId;

      expect(capturedTraceContext, isNotNull);
      expect(capturedTraceId, propagationContextTraceId);
    });

    test('attaches trace context from span if none present yet', () async {
      final client = fixture.getSut();
      final spanContext = SentrySpanContext(
        traceId: SentryId.newId(),
        spanId: SpanId.newId(),
        operation: 'op.load',
      );
      final scope = Scope(fixture.options);
      scope.span = SentrySpan(fixture.tracer, spanContext, MockHub());

      final sentryEvent = SentryEvent();
      await client.captureEvent(sentryEvent, scope: scope);

      expect(fixture.transport.envelopes.length, 1);
      expect(spanContext.spanId, sentryEvent.contexts.trace!.spanId);
      expect(spanContext.traceId, sentryEvent.contexts.trace!.traceId);
    });

    test(
        'attaches trace context from scope if none present yet and no span on scope',
        () async {
      final client = fixture.getSut();

      final scope = Scope(fixture.options);
      final scopePropagationContext = scope.propagationContext;

      final sentryEvent = SentryEvent();
      await client.captureEvent(sentryEvent, scope: scope);

      expect(fixture.transport.envelopes.length, 1);
      expect(
          scopePropagationContext.traceId, sentryEvent.contexts.trace!.traceId);
      expect(
          scopePropagationContext.spanId, sentryEvent.contexts.trace!.spanId);
    });

    test('keeps existing trace context if already present', () async {
      final client = fixture.getSut();

      final spanContext = SentrySpanContext(
        traceId: SentryId.newId(),
        spanId: SpanId.newId(),
        operation: 'op.load',
      );
      final scope = Scope(fixture.options);
      scope.span = SentrySpan(fixture.tracer, spanContext, MockHub());

      final propagationContext = scope.propagationContext;
      final preExistingSpanContext = SentryTraceContext(
          traceId: SentryId.newId(),
          spanId: SpanId.newId(),
          operation: 'op.load');

      final sentryEvent = SentryEvent();
      sentryEvent.contexts.trace = preExistingSpanContext;
      await client.captureEvent(sentryEvent, scope: scope);

      expect(fixture.transport.envelopes.length, 1);
      expect(
          preExistingSpanContext.traceId, sentryEvent.contexts.trace!.traceId);
      expect(preExistingSpanContext.spanId, sentryEvent.contexts.trace!.spanId);
      expect(spanContext.traceId, isNot(sentryEvent.contexts.trace!.traceId));
      expect(spanContext.spanId, isNot(sentryEvent.contexts.trace!.spanId));
      expect(propagationContext.traceId,
          isNot(sentryEvent.contexts.trace!.traceId));
      expect(
          propagationContext.spanId, isNot(sentryEvent.contexts.trace!.spanId));
    });

    test(
        'uses propagation context on scope for trace header if no transaction is on scope',
        () async {
      final client = fixture.getSut();

      final scope = Scope(fixture.options);
      final scopePropagationContext = scope.propagationContext;

      final sentryEvent = SentryEvent();
      await client.captureEvent(sentryEvent, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedTraceContext = capturedEnvelope.header.traceContext;

      expect(fixture.transport.envelopes.length, 1);
      expect(scope.span, isNull);
      expect(capturedTraceContext, isNotNull);
      expect(scopePropagationContext.traceId, capturedTraceContext!.traceId);
    });

    test(
        'uses trace context on transaction for trace header if a transaction is on scope',
        () async {
      final client = fixture.getSut();

      final spanContext = SentrySpanContext(
        traceId: SentryId.newId(),
        spanId: SpanId.newId(),
        operation: 'op.load',
      );
      final scope = Scope(fixture.options);
      scope.span = SentrySpan(fixture.tracer, spanContext, MockHub());

      final sentryEvent = SentryEvent();
      await client.captureEvent(sentryEvent, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedTraceContext = capturedEnvelope.header.traceContext;

      expect(fixture.transport.envelopes.length, 1);
      expect(scope.span, isNotNull);
      expect(capturedTraceContext, isNotNull);
      expect(
          scope.span!.traceContext()!.traceId, capturedTraceContext!.traceId);
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

    test('transaction envelope contains dsn', () async {
      final client = fixture.getSut();
      final tr = SentryTransaction(fixture.tracer);
      await client.captureTransaction(tr);

      final capturedEnvelope = (fixture.transport).envelopes.first;

      expect(capturedEnvelope.header.dsn, fixture.options.dsn);
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
      // ignore: deprecated_member_use_from_same_package
      extra: const {eventExtraKey: eventExtraValue},
      modules: const {eventExtraKey: eventExtraValue},
      level: SentryLevel.warning,
    );

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();

      scope = Scope(fixture.options)
        ..level = level
        ..transaction = transaction
        ..fingerprint = fingerprint
        ..addBreadcrumb(crumb)
        ..setTag(scopeTagKey, scopeTagValue)
        // ignore: deprecated_member_use_from_same_package
        ..setExtra(scopeExtraKey, scopeExtraValue)
        ..replayId = SentryId.fromId('1');

      scope.setUser(user);
    });

    test('should apply the scope to event', () async {
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
      // ignore: deprecated_member_use_from_same_package
      expect(capturedEvent.extra, {
        scopeExtraKey: scopeExtraValue,
        eventExtraKey: eventExtraValue,
      });
      expect(
          capturedEnvelope.header.traceContext?.replayId, SentryId.fromId('1'));
    });

    test('should apply the scope to feedback event', () async {
      final client = fixture.getSut();
      final feedback = fixture.fakeFeedback();
      await client.captureFeedback(feedback, scope: scope);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.id, user.id);
      expect(capturedEvent.level!.name, SentryLevel.error.name);
      expect(capturedEvent.transaction, transaction);
      expect(capturedEvent.fingerprint, fingerprint);
      expect(capturedEvent.breadcrumbs?.first.toJson(), crumb.toJson());
      expect(capturedEvent.tags, {
        scopeTagKey: scopeTagValue,
      });
      // ignore: deprecated_member_use_from_same_package
      expect(capturedEvent.extra, {
        scopeExtraKey: scopeExtraValue,
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

    Future<Scope> createScope(SentryOptions options) async {
      final scope = Scope(options)
        ..transaction = transaction
        ..fingerprint = fingerprint;
      await scope.addBreadcrumb(crumb);
      await scope.setUser(user);
      return scope;
    }

    setUp(() {
      fixture = Fixture();
    });

    test('should not apply the scope to non null event fields', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final scope = await createScope(fixture.options);

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

    test('should apply the scope user to null event user fields', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final scope = await createScope(fixture.options);

      await scope.setUser(SentryUser(id: '987'));

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
      final scope = await createScope(fixture.options);

      await scope.setUser(
        SentryUser(
          id: 'id',
          data: {
            'foo': 'bar',
            'bar': 'foo',
          },
        ),
      );

      var eventWithUser = event.copyWith(
        user: SentryUser(
          id: 'id',
          data: {
            'foo': 'this bar is more important',
            'event': 'Really important event'
          },
        ),
      );
      await client.captureEvent(eventWithUser, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.data?['foo'], 'this bar is more important');
      expect(capturedEvent.user?.data?['bar'], 'foo');
      expect(capturedEvent.user?.data?['event'], 'Really important event');
    });
  });

  group('SentryClient: sets user & user ip', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('event has no user', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      var fakeEvent = SentryEvent();

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, '{{auto}}');
    });

    test('event has a user with IP address', () async {
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

    test('event has a user without IP address', () async {
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

      expect(fixture.transport.called(1), true);
    });

    test('do not capture event, sample rate is 0% disabled', () async {
      final client = fixture.getSut(sampleRate: 0.0);
      await client.captureEvent(fakeEvent);

      expect(fixture.transport.called(0), true);
    });

    test('captures event, sample rate is null, disabled', () async {
      final client = fixture.getSut();
      await client.captureEvent(fakeEvent);

      expect(fixture.transport.called(1), true);
    });

    test('capture feedback event, sample rate is 0% disabled', () async {
      final client = fixture.getSut(sampleRate: 0.0);

      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      expect(fixture.transport.called(1), true);
    });
  });

  group('SentryClient ignored errors', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      fixture.options.ignoreErrors = ["my-error", "^error-.*\$"];
    });

    test('drop event if error message fully matches ignoreErrors value',
        () async {
      final event = SentryEvent(message: SentryMessage("my-error"));

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.transport.called(0), true);
    });

    test('drop event if error message partially matches ignoreErrors value',
        () async {
      final event = SentryEvent(message: SentryMessage("this is my-error-foo"));

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.transport.called(0), true);
    });

    test(
        'drop event if error message partially matches ignoreErrors regex value',
        () async {
      final event = SentryEvent(message: SentryMessage("error-test message"));

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.transport.called(0), true);
    });

    test('send event if error message does not match ignoreErrors value',
        () async {
      final event = SentryEvent(message: SentryMessage("warning"));

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.transport.called(1), true);
    });

    test('send event if no values are set for ignoreErrors', () async {
      fixture.options.ignoreErrors = [];
      final event = SentryEvent(message: SentryMessage("this is a test event"));

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.transport.called(1), true);
    });
  });

  group('SentryClient ignored transactions', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      fixture.options.ignoreTransactions = [
        "my-transaction",
        "^transaction-.*\$"
      ];
    });

    test('drop transaction if name fully matches ignoreTransaction value',
        () async {
      final client = fixture.getSut();
      final fakeTransaction = fixture.fakeTransaction();
      fakeTransaction.tracer.name = "my-transaction";
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(0), true);
    });

    test('drop transaction if name partially matches ignoreTransaction value',
        () async {
      final client = fixture.getSut();
      final fakeTransaction = fixture.fakeTransaction();
      fakeTransaction.tracer.name = "this is a my-transaction-test";
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(0), true);
    });

    test(
        'drop transaction if name partially matches ignoreTransaction regex value',
        () async {
      final client = fixture.getSut();
      final fakeTransaction = fixture.fakeTransaction();
      fakeTransaction.tracer.name = "transaction-test message";
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(0), true);
    });

    test('send transaction if name does not match ignoreTransaction value',
        () async {
      final client = fixture.getSut();
      final fakeTransaction = fixture.fakeTransaction();
      fakeTransaction.tracer.name = "capture";
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(1), true);
    });

    test('send transaction if no values are set for ignoreTransaction',
        () async {
      fixture.options.ignoreTransactions = [];
      final client = fixture.getSut();
      final fakeTransaction = fixture.fakeTransaction();
      fakeTransaction.tracer.name = "this is a test transaction";
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(1), true);
    });
  });

  group('SentryClient ignored exceptions', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('addExceptionFilterForType drops matching error event throwable',
        () async {
      fixture.options.addExceptionFilterForType(ExceptionWithCause);

      final throwable = ExceptionWithCause(Error(), StackTrace.current);
      final event = SentryEvent(throwable: throwable);

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.transport.called(0), true);
    });

    test('record ignored exceptions dropping event', () async {
      fixture.options.addExceptionFilterForType(ExceptionWithCause);

      final throwable = ExceptionWithCause(Error(), StackTrace.current);
      final event = SentryEvent(throwable: throwable);

      final client = fixture.getSut();
      await client.captureEvent(event);

      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.eventProcessor);
      expect(
          fixture.recorder.discardedEvents.first.category, DataCategory.error);
    });
  });

  group('SentryClient before send feedback', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('before send feedback drops event', () async {
      final client = fixture.getSut(
          beforeSendFeedback: beforeSendFeedbackCallbackDropEvent);
      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      expect(fixture.transport.called(0), true);
    });

    test('async before send feedback drops event', () async {
      final client = fixture.getSut(
          beforeSendFeedback: asyncBeforeSendFeedbackCallbackDropEvent);
      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      expect(fixture.transport.called(0), true);
    });

    test(
        'before send feedback returns an feedback event and feedback event is captured',
        () async {
      final client =
          fixture.getSut(beforeSendFeedback: beforeSendFeedbackCallback);
      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final feedbackEvent = await eventFromEnvelope(capturedEnvelope);

      expect(feedbackEvent.tags!.containsKey('theme'), true);
    });

    test('thrown error is handled', () async {
      fixture.options.automatedTestMode = false;
      final exception = Exception("before send exception");
      final beforeSendFeedbackCallback = (SentryEvent event, Hint hint) {
        throw exception;
      };

      final client = fixture.getSut(
          beforeSendFeedback: beforeSendFeedbackCallback, debug: true);
      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      expect(fixture.loggedException, exception);
      expect(fixture.loggedLevel, SentryLevel.error);
    });
  });

  group('SentryClient before send transaction', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('before send transaction drops event', () async {
      final client = fixture.getSut(
          beforeSendTransaction: beforeSendTransactionCallbackDropEvent);
      final fakeTransaction = fixture.fakeTransaction();
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(0), true);
    });

    test('async before send transaction drops event', () async {
      final client = fixture.getSut(
          beforeSendTransaction: asyncBeforeSendTransactionCallbackDropEvent);
      final fakeTransaction = fixture.fakeTransaction();
      await client.captureTransaction(fakeTransaction);

      expect(fixture.transport.called(0), true);
    });

    test(
        'before send transaction returns an transaction and transaction is captured',
        () async {
      final client =
          fixture.getSut(beforeSendTransaction: beforeSendTransactionCallback);
      final fakeTransaction = fixture.fakeTransaction();
      await client.captureTransaction(fakeTransaction);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final transaction = await transactionFromEnvelope(capturedEnvelope);

      expect(transaction['tags']!.containsKey('theme'), true);
      expect(transaction['extra']!.containsKey('host'), true);
      expect(transaction['sdk']!['integrations'].contains('testIntegration'),
          true);
      expect(
        transaction['sdk']!['packages']
            .any((element) => element['name'] == 'test-pkg'),
        true,
      );
      expect(
        transaction['breadcrumbs']!
            .any((element) => element['message'] == 'processor crumb'),
        true,
      );
    });

    test('thrown error is handled', () async {
      fixture.options.automatedTestMode = false;
      final exception = Exception("before send exception");
      final beforeSendTransactionCallback = (SentryTransaction event) {
        throw exception;
      };

      fixture.options.automatedTestMode = false;
      final client = fixture.getSut(
          beforeSendTransaction: beforeSendTransactionCallback, debug: true);
      final fakeTransaction = fixture.fakeTransaction();
      await client.captureTransaction(fakeTransaction);

      expect(fixture.loggedException, exception);
      expect(fixture.loggedLevel, SentryLevel.error);
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

      expect(fixture.transport.called(0), true);
    });

    test('async before send drops event', () async {
      final client =
          fixture.getSut(beforeSend: asyncBeforeSendCallbackDropEvent);
      await client.captureEvent(fakeEvent);

      expect(fixture.transport.called(0), true);
    });

    test('before send returns an event and event is captured', () async {
      final client = fixture.getSut(beforeSend: beforeSendCallback);
      await client.captureEvent(fakeEvent);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final event = await eventFromEnvelope(capturedEnvelope);

      expect(event.tags!.containsKey('theme'), true);
      // ignore: deprecated_member_use_from_same_package
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

    test('thrown error is handled', () async {
      fixture.options.automatedTestMode = false;
      final exception = Exception("before send exception");
      final beforeSendCallback = (SentryEvent event, Hint hint) {
        throw exception;
      };

      fixture.options.automatedTestMode = false;
      final client =
          fixture.getSut(beforeSend: beforeSendCallback, debug: true);

      await client.captureEvent(fakeEvent);

      expect(fixture.loggedException, exception);
      expect(fixture.loggedLevel, SentryLevel.error);
    });
  });

  group('EventProcessors', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
      fixture.options.addEventProcessor(FunctionEventProcessor(
        (event, hint) => event.copyWith(tags: {'theme': 'material'})
          // ignore: deprecated_member_use_from_same_package
          ..extra?['host'] = '0.0.0.1'
          ..modules?.addAll({'core': '1.0'})
          ..breadcrumbs?.add(Breadcrumb(message: 'processor crumb'))
          ..fingerprint?.add('process')
          ..sdk?.addIntegration('testIntegration')
          ..sdk?.addPackage('test-pkg', '1.0'),
      ));
    });

    test('should execute eventProcessors for event', () async {
      final client = fixture.getSut();
      await client.captureEvent(fakeEvent);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final event = await eventFromEnvelope(capturedEnvelope);

      expect(event.tags!.containsKey('theme'), true);
      // ignore: deprecated_member_use_from_same_package
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

    test('should execute eventProcessors for feedback', () async {
      final client = fixture.getSut();
      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final event = await eventFromEnvelope(capturedEnvelope);

      expect(event.tags?.containsKey('theme'), true);
    });

    test('should pass hint to eventProcessors for event', () async {
      final myHint = Hint();
      myHint.set('string', 'hint');

      var executed = false;

      final client =
          fixture.getSut(eventProcessor: FunctionEventProcessor((event, hint) {
        expect(myHint, hint);
        executed = true;
        return event;
      }));

      await client.captureEvent(fakeEvent, hint: myHint);

      expect(executed, true);
    });

    test('should pass hint to eventProcessors for feedback', () async {
      final myHint = Hint();
      myHint.set('string', 'hint');

      var executed = false;

      final client =
          fixture.getSut(eventProcessor: FunctionEventProcessor((event, hint) {
        expect(myHint, hint);
        executed = true;
        return event;
      }));

      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback, hint: myHint);

      expect(executed, true);
    });

    test('should create hint when none was provided for event', () async {
      var executed = false;

      final client =
          fixture.getSut(eventProcessor: FunctionEventProcessor((event, hint) {
        expect(hint, isNotNull);
        executed = true;
        return event;
      }));

      await client.captureEvent(fakeEvent);

      expect(executed, true);
    });

    test('should create hint when none was provided for feedback event',
        () async {
      var executed = false;

      final client =
          fixture.getSut(eventProcessor: FunctionEventProcessor((event, hint) {
        expect(hint, isNotNull);
        executed = true;
        return event;
      }));

      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      expect(executed, true);
    });

    test('event processor drops the event', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      await client.captureEvent(fakeEvent);

      expect(fixture.transport.called(0), true);
    });

    test('event processor drops the feedback event', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback);

      expect(fixture.transport.called(0), true);
    });
  });

  group('SentryClient captures feedback', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should capture feedback as event', () async {
      final client = fixture.getSut();

      final feedback = fixture.fakeFeedback();
      await client.captureFeedback(feedback);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final envelopeItem = capturedEnvelope.items.first;
      final envelopeEvent = envelopeItem.originalObject as SentryEvent?;

      expect(envelopeItem, isNotNull);
      expect(envelopeEvent, isNotNull);

      expect(envelopeItem.header.type, 'feedback');

      expect(envelopeEvent?.type, 'feedback');
      expect(envelopeEvent?.contexts.feedback?.toJson(), feedback.toJson());
      expect(envelopeEvent?.level, SentryLevel.info);
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

  group('ClientReportRecorder', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('recorder is not noop if client reports are enabled', () async {
      fixture.options.sendClientReports = true;

      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
      );

      expect(fixture.options.recorder is NoOpClientReportRecorder, false);
      expect(fixture.options.recorder is MockClientReportRecorder, false);
    });

    test('recorder is noop if client reports are disabled', () {
      fixture.options.sendClientReports = false;

      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
      );

      expect(fixture.options.recorder is NoOpClientReportRecorder, true);
    });

    test('captureEnvelope calls flush', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      await client.captureEnvelope(envelope);

      expect(fixture.recorder.flushCalled, true);
    });

    test('captureEnvelope adds client report', () async {
      final clientReport = ClientReport(
        DateTime(0),
        [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
      );
      fixture.recorder.clientReport = clientReport;

      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      final envelope = MockEnvelope();
      envelope.items = [SentryEnvelopeItem.fromEvent(SentryEvent())];

      await client.captureEnvelope(envelope);

      expect(envelope.clientReport, clientReport);
    });

    test('captureEvent adds trace context', () async {
      final client = fixture.getSut();

      final scope = Scope(fixture.options);
      scope.replayId = SentryId.newId();
      scope.span =
          SentrySpan(fixture.tracer, fixture.tracer.context, MockHub());

      await client.captureEvent(fakeEvent, scope: scope);

      final envelope = fixture.transport.envelopes.first;
      expect(envelope.header.traceContext, isNotNull);
      expect(envelope.header.traceContext?.replayId, scope.replayId);
    });

    test('captureEvent adds attachments from hint', () async {
      final attachment = SentryAttachment.fromIntList([], "fixture-fileName");
      final hint = Hint.withAttachment(attachment);

      final sut = fixture.getSut();
      await sut.captureEvent(fakeEvent, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = IterableUtils.firstWhereOrNull(
        capturedEnvelope.items,
        (SentryEnvelopeItem e) => e.header.type == SentryItemType.attachment,
      );
      expect(attachmentItem?.header.attachmentType,
          SentryAttachment.typeAttachmentDefault);
    });

    test('captureEvent adds screenshot from hint', () async {
      final client = fixture.getSut();
      final screenshot =
          SentryAttachment.fromScreenshotData(Uint8List.fromList([0, 0, 0, 0]));
      final hint = Hint.withScreenshot(screenshot);

      await client.captureEvent(fakeEvent, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = capturedEnvelope.items.firstWhereOrNull(
          (element) => element.header.type == SentryItemType.attachment);
      expect(attachmentItem?.header.fileName, 'screenshot.png');
    });

    test('captureEvent adds viewHierarchy from hint', () async {
      final client = fixture.getSut();
      final view = SentryViewHierarchy('flutter');
      final attachment = SentryAttachment.fromViewHierarchy(view);
      final hint = Hint.withViewHierarchy(attachment);

      await client.captureEvent(fakeEvent, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = capturedEnvelope.items.firstWhereOrNull(
          (element) => element.header.type == SentryItemType.attachment);

      expect(attachmentItem?.header.attachmentType,
          SentryAttachment.typeViewHierarchy);
    });

    test('captureTransaction adds trace context', () async {
      final client = fixture.getSut();

      final tr = SentryTransaction(fixture.tracer);

      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${tr.eventId}',
        'public_key': '123',
        'replay_id': '456',
      });

      await client.captureTransaction(tr, traceContext: context);

      final envelope = fixture.transport.envelopes.first;
      expect(envelope.header.traceContext, isNotNull);
      expect(envelope.header.traceContext?.replayId, SentryId.fromId('456'));
    });

    test('captureUserFeedback calls flush', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      final id = SentryId.newId();
      // ignore: deprecated_member_use_from_same_package
      final feedback = SentryUserFeedback(
        eventId: id,
        comments: 'this is awesome',
        email: 'sentry@example.com',
        name: 'Rockstar Developer',
      );
      // ignore: deprecated_member_use_from_same_package
      await client.captureUserFeedback(feedback);

      expect(fixture.recorder.flushCalled, true);
    });

    test('captureUserFeedback adds client report', () async {
      final clientReport = ClientReport(
        DateTime(0),
        [DiscardedEvent(DiscardReason.rateLimitBackoff, DataCategory.error, 1)],
      );
      fixture.recorder.clientReport = clientReport;

      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      final id = SentryId.newId();
      // ignore: deprecated_member_use_from_same_package
      final feedback = SentryUserFeedback(
        eventId: id,
        comments: 'this is awesome',
        email: 'sentry@example.com',
        name: 'Rockstar Developer',
      );
      // ignore: deprecated_member_use_from_same_package
      await client.captureUserFeedback(feedback);

      final envelope = fixture.transport.envelopes.first;
      final item = envelope.items.last;

      // Only partial test, as the envelope is created internally from feedback.
      expect(item.header.type, SentryItemType.clientReport);
    });

    test('record event processor dropping event', () async {
      bool secondProcessorCalled = false;
      fixture.options.addEventProcessor(DropAllEventProcessor());
      fixture.options.addEventProcessor(FunctionEventProcessor((event, hint) {
        secondProcessorCalled = true;
        return event;
      }));
      final client = fixture.getSut();

      await client.captureEvent(fakeEvent);

      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.eventProcessor);
      expect(
          fixture.recorder.discardedEvents.first.category, DataCategory.error);
      expect(secondProcessorCalled, isFalse);
    });

    test('record event processor dropping transaction', () async {
      final sut = fixture.getSut(eventProcessor: DropAllEventProcessor());
      final transaction = SentryTransaction(fixture.tracer);
      fixture.tracer.startChild('child1');
      fixture.tracer.startChild('child2');
      fixture.tracer.startChild('child3');

      await sut.captureTransaction(transaction);

      expect(fixture.recorder.discardedEvents.length, 2);

      final spanCount = fixture.recorder.discardedEvents
          .firstWhere((element) =>
              element.category == DataCategory.span &&
              element.reason == DiscardReason.eventProcessor)
          .quantity;
      expect(spanCount, 4);
    });

    test('record event processor dropping partially spans', () async {
      final numberOfSpansDropped = 2;
      final sut = fixture.getSut(
          eventProcessor: DropSpansEventProcessor(numberOfSpansDropped));
      final transaction = SentryTransaction(fixture.tracer);
      fixture.tracer.startChild('child1');
      fixture.tracer.startChild('child2');
      fixture.tracer.startChild('child3');

      await sut.captureTransaction(transaction);

      expect(fixture.recorder.discardedEvents.length, 1);

      final spanCount = fixture.recorder.discardedEvents
          .firstWhere((element) =>
              element.category == DataCategory.span &&
              element.reason == DiscardReason.eventProcessor)
          .quantity;
      expect(spanCount, numberOfSpansDropped);
    });

    test('beforeSendTransaction correctly records partially dropped spans',
        () async {
      final sut = fixture.getSut();
      final transaction = SentryTransaction(fixture.tracer);
      fixture.tracer.startChild('child1');
      fixture.tracer.startChild('child2');
      fixture.tracer.startChild('child3');

      fixture.options.beforeSendTransaction = (transaction) {
        if (transaction.tracer == fixture.tracer) {
          return null;
        }
        return transaction;
      };

      await sut.captureTransaction(transaction);

      expect(fixture.recorder.discardedEvents.length, 2);

      final spanCount = fixture.recorder.discardedEvents
          .firstWhere((element) =>
              element.category == DataCategory.span &&
              element.reason == DiscardReason.beforeSend)
          .quantity;
      expect(spanCount, 4);
    });

    test('beforeSendTransaction correctly records partially dropped spans',
        () async {
      final sut = fixture.getSut();
      final transaction = SentryTransaction(fixture.tracer);
      fixture.tracer.startChild('child1');
      fixture.tracer.startChild('child2');
      fixture.tracer.startChild('child3');

      fixture.options.beforeSendTransaction = (transaction) {
        if (transaction.tracer == fixture.tracer) {
          transaction.spans
              .removeWhere((element) => element.context.operation == 'child2');
          return transaction;
        }
        return transaction;
      };

      await sut.captureTransaction(transaction);

      // we didn't drop the whole transaction, we only have 1 event for the dropped spans
      expect(fixture.recorder.discardedEvents.length, 1);

      // tracer has 3 span children and we dropped 1 of them
      final spanCount = fixture.recorder.discardedEvents
          .firstWhere((element) =>
              element.category == DataCategory.span &&
              element.reason == DiscardReason.beforeSend)
          .quantity;
      expect(spanCount, 1);
    });

    test('record event processor dropping transaction', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());

      final context = SentryTransactionContext('name', 'op');
      final tracer = SentryTracer(context, MockHub());
      final transaction = SentryTransaction(tracer);

      await client.captureTransaction(transaction);

      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.eventProcessor);
      expect(fixture.recorder.discardedEvents.first.category,
          DataCategory.transaction);
    });

    test('record beforeSend dropping event', () async {
      final client = fixture.getSut();

      fixture.options.beforeSend = fixture.droppingBeforeSend;

      await client.captureEvent(fakeEvent);

      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.beforeSend);
      expect(
          fixture.recorder.discardedEvents.first.category, DataCategory.error);
    });

    test('record sample rate dropping event', () async {
      final client = fixture.getSut(sampleRate: 0.0);

      fixture.options.beforeSend = fixture.droppingBeforeSend;

      await client.captureEvent(fakeEvent);

      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.sampleRate);
      expect(
          fixture.recorder.discardedEvents.first.category, DataCategory.error);
    });

    test('user feedback envelope contains dsn', () async {
      final client = fixture.getSut();
      final event = SentryEvent();
      // ignore: deprecated_member_use_from_same_package
      final feedback = SentryUserFeedback(
        eventId: event.eventId,
        name: 'test',
      );
      // ignore: deprecated_member_use_from_same_package
      await client.captureUserFeedback(feedback);

      final capturedEnvelope = (fixture.transport).envelopes.first;

      expect(capturedEnvelope.header.dsn, fixture.options.dsn);
    });

    test(
        'Spotlight enabled should not set transport to SpotlightHttpTransport on iOS',
        () async {
      fixture.options.platformChecker = MockPlatformChecker(
        platform: MockPlatform.iOS(),
      );
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isFalse);
    });

    test(
        'Spotlight enabled should not set transport to SpotlightHttpTransport on macOS',
        () async {
      fixture.options.platformChecker = MockPlatformChecker(
        platform: MockPlatform.macOS(),
      );
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isFalse);
    });

    test(
        'Spotlight enabled should not set transport to SpotlightHttpTransport on Android',
        () async {
      fixture.options.platformChecker = MockPlatformChecker(
        platform: MockPlatform.android(),
      );
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isFalse);
    });

    test(
        'Spotlight enabled should set transport to SpotlightHttpTransport on Web',
        () async {
      fixture.options.platformChecker = MockPlatformChecker(isWebValue: true);
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isTrue);
    });

    test(
        'Spotlight enabled should set transport to SpotlightHttpTransport on Linux',
        () async {
      fixture.options.platformChecker =
          MockPlatformChecker(platform: MockPlatform.linux());
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isTrue);
    });

    test(
        'Spotlight enabled should set transport to SpotlightHttpTransport on Windows',
        () async {
      fixture.options.platformChecker =
          MockPlatformChecker(platform: MockPlatform.windows());
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isTrue);
    });
  });

  group('trace context', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('captureEvent adds trace context', () async {
      final client = fixture.getSut();

      final scope = Scope(fixture.options);
      scope.span =
          SentrySpan(fixture.tracer, fixture.tracer.context, MockHub());

      await client.captureEvent(fakeEvent, scope: scope);

      final envelope = fixture.transport.envelopes.first;
      expect(envelope.header.traceContext, isNotNull);
    });

    test('captureTransaction adds trace context', () async {
      final client = fixture.getSut();

      final tr = SentryTransaction(fixture.tracer);

      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${tr.eventId}',
        'public_key': '123',
      });

      await client.captureTransaction(tr, traceContext: context);

      final envelope = fixture.transport.envelopes.first;
      expect(envelope.header.traceContext, isNotNull);
    });

    test('captureFeedback adds trace context', () async {
      final client = fixture.getSut();

      final scope = Scope(fixture.options);
      scope.span =
          SentrySpan(fixture.tracer, fixture.tracer.context, MockHub());

      await client.captureFeedback(fixture.fakeFeedback(), scope: scope);

      final envelope = fixture.transport.envelopes.first;
      expect(envelope.header.traceContext, isNotNull);
    });
  });

  group('Hint', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('captureEvent adds attachments from hint', () async {
      final attachment = SentryAttachment.fromIntList([], "fixture-fileName");
      final hint = Hint.withAttachment(attachment);

      final sut = fixture.getSut();
      await sut.captureEvent(fakeEvent, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = IterableUtils.firstWhereOrNull(
        capturedEnvelope.items,
        (SentryEnvelopeItem e) => e.header.type == SentryItemType.attachment,
      );
      expect(attachmentItem?.header.attachmentType,
          SentryAttachment.typeAttachmentDefault);
    });

    test('captureFeedback adds attachments from hint', () async {
      final attachment = SentryAttachment.fromIntList([], "fixture-fileName");
      final hint = Hint.withAttachment(attachment);

      final sut = fixture.getSut();
      final fakeFeedback = fixture.fakeFeedback();
      await sut.captureFeedback(fakeFeedback, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = IterableUtils.firstWhereOrNull(
        capturedEnvelope.items,
        (SentryEnvelopeItem e) => e.header.type == SentryItemType.attachment,
      );
      expect(attachmentItem?.header.attachmentType,
          SentryAttachment.typeAttachmentDefault);
    });

    test('captureEvent adds screenshot from hint', () async {
      final client = fixture.getSut();
      final screenshot =
          SentryAttachment.fromScreenshotData(Uint8List.fromList([0, 0, 0, 0]));
      final hint = Hint.withScreenshot(screenshot);

      await client.captureEvent(fakeEvent, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = capturedEnvelope.items.firstWhereOrNull(
          (element) => element.header.type == SentryItemType.attachment);
      expect(attachmentItem?.header.fileName, 'screenshot.png');
    });

    test('captureFeedback adds screenshot from hint', () async {
      final client = fixture.getSut();
      final screenshot =
          SentryAttachment.fromScreenshotData(Uint8List.fromList([0, 0, 0, 0]));
      final hint = Hint.withScreenshot(screenshot);

      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = capturedEnvelope.items.firstWhereOrNull(
          (element) => element.header.type == SentryItemType.attachment);
      expect(attachmentItem?.header.fileName, 'screenshot.png');
    });

    test('captureEvent adds viewHierarchy from hint', () async {
      final client = fixture.getSut();
      final view = SentryViewHierarchy('flutter');
      final attachment = SentryAttachment.fromViewHierarchy(view);
      final hint = Hint.withViewHierarchy(attachment);

      await client.captureEvent(fakeEvent, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = capturedEnvelope.items.firstWhereOrNull(
          (element) => element.header.type == SentryItemType.attachment);

      expect(attachmentItem?.header.attachmentType,
          SentryAttachment.typeViewHierarchy);
    });

    test('captureFeedback does not add viewHierarchy from hint', () async {
      final client = fixture.getSut();
      final view = SentryViewHierarchy('flutter');
      final attachment = SentryAttachment.fromViewHierarchy(view);
      final hint = Hint.withViewHierarchy(attachment);

      final fakeFeedback = fixture.fakeFeedback();
      await client.captureFeedback(fakeFeedback, hint: hint);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final attachmentItem = capturedEnvelope.items.firstWhereOrNull(
          (element) => element.header.type == SentryItemType.attachment);

      expect(attachmentItem, isNull);
    });
  });

  group('Capture metrics', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('metricsAggregator is set if metrics are enabled', () async {
      final client = fixture.getSut(enableMetrics: true);
      expect(client.metricsAggregator, isNotNull);
    });

    test('metricsAggregator is null if metrics are disabled', () async {
      final client = fixture.getSut(enableMetrics: false);
      expect(client.metricsAggregator, isNull);
    });

    test('captureMetrics send statsd envelope', () async {
      final client = fixture.getSut();
      await client.captureMetrics(fakeMetrics);

      final capturedStatsd = (fixture.transport).statsdItems.first;
      expect(capturedStatsd, isNotNull);
    });

    test('close closes metricsAggregator', () async {
      final client = fixture.getSut();
      client.close();
      expect(client.metricsAggregator, isNotNull);
      client.metricsAggregator!
          .emit(MetricType.counter, 'key', 1, SentryMeasurementUnit.none, {});
      // metricsAggregator is closed, so no metrics should be recorded
      expect(client.metricsAggregator!.buckets, isEmpty);
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

SentryEvent? beforeSendCallbackDropEvent(
  SentryEvent event,
  Hint hint,
) =>
    null;

SentryTransaction? beforeSendFeedbackCallbackDropEvent(
  SentryEvent feedbackEvent,
  Hint hint,
) =>
    null;

Future<SentryEvent?> asyncBeforeSendFeedbackCallbackDropEvent(
  SentryEvent feedbackEvent,
  Hint hint,
) async {
  await Future.delayed(Duration(milliseconds: 200));
  return null;
}

SentryTransaction? beforeSendTransactionCallbackDropEvent(
  SentryTransaction event,
) =>
    null;

Future<SentryEvent?> asyncBeforeSendCallbackDropEvent(
  SentryEvent event,
  Hint hint,
) async {
  await Future.delayed(Duration(milliseconds: 200));
  return null;
}

Future<SentryTransaction?> asyncBeforeSendTransactionCallbackDropEvent(
    SentryEvent event) async {
  await Future.delayed(Duration(milliseconds: 200));
  return null;
}

SentryEvent? beforeSendFeedbackCallback(SentryEvent event, Hint hint) {
  return event.copyWith(tags: {'theme': 'material'});
}

SentryEvent? beforeSendCallback(SentryEvent event, Hint hint) {
  return event
    ..tags!.addAll({'theme': 'material'})
    // ignore: deprecated_member_use_from_same_package
    ..extra!['host'] = '0.0.0.1'
    ..modules!.addAll({'core': '1.0'})
    ..breadcrumbs!.add(Breadcrumb(message: 'processor crumb'))
    ..fingerprint!.add('process')
    ..sdk!.addIntegration('testIntegration')
    ..sdk!.addPackage('test-pkg', '1.0');
}

SentryTransaction? beforeSendTransactionCallback(
    SentryTransaction transaction) {
  return transaction
    ..tags!.addAll({'theme': 'material'})
    // ignore: deprecated_member_use_from_same_package
    ..extra!['host'] = '0.0.0.1'
    ..sdk!.addIntegration('testIntegration')
    ..sdk!.addPackage('test-pkg', '1.0')
    ..breadcrumbs!.add(Breadcrumb(message: 'processor crumb'));
}

class Fixture {
  final recorder = MockClientReportRecorder();
  final transport = MockTransport();

  final options =
      defaultTestOptions(MockPlatformChecker(platform: MockPlatform.iOS()));

  late SentryTransactionContext _context;
  late SentryTracer tracer;

  SentryLevel? loggedLevel;
  Object? loggedException;

  SentryClient getSut({
    bool sendDefaultPii = false,
    bool attachStacktrace = true,
    bool attachThreads = false,
    bool enableMetrics = true,
    double? sampleRate,
    BeforeSendCallback? beforeSend,
    BeforeSendTransactionCallback? beforeSendTransaction,
    BeforeSendCallback? beforeSendFeedback,
    EventProcessor? eventProcessor,
    bool provideMockRecorder = true,
    bool debug = false,
  }) {
    final hub = Hub(options);
    _context = SentryTransactionContext(
      'name',
      'op',
    );
    tracer = SentryTracer(_context, hub);

    options.tracesSampleRate = 1.0;
    options.sendDefaultPii = sendDefaultPii;
    options.enableMetrics = enableMetrics;
    options.attachStacktrace = attachStacktrace;
    options.attachThreads = attachThreads;
    options.sampleRate = sampleRate;
    options.beforeSend = beforeSend;
    options.beforeSendTransaction = beforeSendTransaction;
    options.beforeSendFeedback = beforeSendFeedback;
    options.debug = debug;
    options.logger = mockLogger;

    if (eventProcessor != null) {
      options.addEventProcessor(eventProcessor);
    }
    options.transport = transport;
    final client = SentryClient(options);

    if (provideMockRecorder) {
      options.recorder = recorder;
    }
    return client;
  }

  Future<SentryEvent?> droppingBeforeSend(SentryEvent event, Hint hint) async {
    return null;
  }

  SentryTransaction fakeTransaction() {
    return SentryTransaction(
      tracer,
      sdk: SdkVersion(name: 'sdk1', version: '1.0.0'),
      breadcrumbs: [],
    );
  }

  SentryEvent fakeFeedbackEvent() {
    return SentryEvent(
      type: 'feedback',
      contexts: Contexts(feedback: fakeFeedback()),
      level: SentryLevel.info,
    );
  }

  SentryFeedback fakeFeedback() {
    return SentryFeedback(
      message: 'fixture-message',
      contactEmail: 'fixture-contactEmail',
      name: 'fixture-name',
      replayId: 'fixture-replayId',
      url: "https://fixture-url.com",
      associatedEventId: SentryId.fromId('1d49af08b6e2c437f9052b1ecfd83dca'),
    );
  }

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedLevel = level;
    loggedException = exception;
  }
}

class ExceptionWithCause {
  ExceptionWithCause(this.cause, this.stackTrace);

  final dynamic cause;
  final dynamic stackTrace;
}

class ExceptionWithCauseExtractor
    extends ExceptionCauseExtractor<ExceptionWithCause> {
  @override
  ExceptionCause? cause(ExceptionWithCause error) {
    return ExceptionCause(error.cause, error.stackTrace);
  }
}

class ExceptionWithStackTrace {
  ExceptionWithStackTrace(this.stackTrace);

  final StackTrace stackTrace;
}

class ExceptionWithStackTraceExtractor
    extends ExceptionStackTraceExtractor<ExceptionWithStackTrace> {
  @override
  StackTrace? stackTrace(ExceptionWithStackTrace error) {
    return error.stackTrace;
  }
}
