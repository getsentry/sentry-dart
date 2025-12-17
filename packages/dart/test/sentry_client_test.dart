import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/client_reports/noop_client_report_recorder.dart';
import 'package:sentry/src/event_processor/exception/exception_group_event_processor.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry/src/sentry_item_type.dart';
import 'package:sentry/src/sentry_stack_trace_factory.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/telemetry_processing/telemetry_processor.dart';
import 'package:sentry/src/transport/client_report_transport.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:sentry/src/transport/noop_transport.dart';
import 'package:sentry/src/transport/spotlight_http_transport.dart';
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:test/test.dart';
import 'package:sentry/src/noop_log_batcher.dart';
import 'package:sentry/src/sentry_log_batcher.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

import 'mocks.dart';
import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_hub.dart';
import 'mocks/mock_transport.dart';
import 'test_utils.dart';
import 'utils/url_details_test.dart';
import 'mocks/mock_log_batcher.dart';

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

      final client = fixture.getSut(
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?.length, 2);

      final firstException = capturedEvent.exceptions?[0];
      expect(firstException is SentryException, true);
      expect(firstException?.mechanism?.source, "cause");
      expect(firstException?.mechanism?.parentId, 0);
      expect(firstException?.mechanism?.exceptionId, 1);
      expect(firstException?.mechanism?.isExceptionGroup, isNull);

      final secondException = capturedEvent.exceptions?[1];
      expect(secondException is SentryException, true);
      expect(secondException?.mechanism?.source, null);
      expect(secondException?.mechanism?.parentId, null);
      expect(secondException?.mechanism?.exceptionId, 0);
      expect(secondException?.mechanism?.isExceptionGroup, isTrue);
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

      final client = fixture.getSut(
        attachStacktrace: true,
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[0].stackTrace, isNotNull);
      expect(capturedEvent.exceptions?[0].stackTrace!.frames.first.fileName,
          'test.dart');
      expect(capturedEvent.exceptions?[0].stackTrace!.frames.first.lineNo, 46);
      expect(capturedEvent.exceptions?[0].stackTrace!.frames.first.colNo, 9);
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

      final client = fixture.getSut(
        attachStacktrace: true,
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
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

      final client = fixture.getSut(
        attachStacktrace: false,
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[0].stackTrace, isNull);
    });

    test(
        'should not capture cause stacktrace when attachStacktrace is false and StackTrace.empty',
        () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      exception = ExceptionWithCause(cause, StackTrace.empty);

      final client = fixture.getSut(
        attachStacktrace: false,
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[0].stackTrace, isNull);
    });

    test('should capture cause exception with Stackframe.current', () async {
      fixture.options.addExceptionCauseExtractor(
        ExceptionWithCauseExtractor(),
      );

      final cause = Object();
      exception = ExceptionWithCause(cause, null);

      final client = fixture.getSut(
        attachStacktrace: true,
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.exceptions?[0].stackTrace, isNotNull);
    });

    test('should capture sentry frames exception', () async {
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

      final client = fixture.getSut(
        attachStacktrace: true,
        eventProcessor: ExceptionGroupEventProcessor(fixture.options),
      );
      await client.captureException(exception, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      final sentryFramesCount = capturedEvent.exceptions?[0].stackTrace!.frames
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

    test('should remove sentry frames if null stackStrace', () async {
      final throwable = Object();

      final client = fixture.getSut(attachStacktrace: true);
      await client.captureException(throwable, stackTrace: null);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      final sentryFramesCount = capturedEvent.exceptions?[0].stackTrace!.frames
          .where((frame) => frame.package == 'sentry')
          .length;

      expect(sentryFramesCount, 0);
    });

    test('should remove sentry frames if empty stackStrace', () async {
      final throwable = Object();

      final client = fixture.getSut(attachStacktrace: true);
      await client.captureException(throwable, stackTrace: StackTrace.empty);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      final sentryFramesCount = capturedEvent.exceptions?[0].stackTrace!.frames
          .where((frame) => frame.package == 'sentry')
          .length;

      expect(sentryFramesCount, 0);
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
      // not checking for span id as it should be a new generated random span id
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
      expect(capturedEvent.breadcrumbs, isNull);
      expect(capturedEvent.tags, {
        scopeTagKey: scopeTagValue,
      });
      // ignore: deprecated_member_use_from_same_package
      expect(capturedEvent.extra, isNull);
    });
  });

  group('SentryClient : apply partial scope to the captured event', () {
    late Fixture fixture;

    late String transaction;
    late String eventTransaction;
    late List<String> fingerprint;
    late List<String> eventFingerprint;
    late SentryUser user;
    late Breadcrumb crumb;
    late SentryUser eventUser;
    late List<Breadcrumb> eventCrumbs;
    late SentryEvent event;

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

      transaction = '/test/scope';
      eventTransaction = '/event/transaction';
      fingerprint = ['foo', 'bar', 'baz'];
      eventFingerprint = ['123', '456', '798'];
      user = SentryUser(id: '123');
      crumb = Breadcrumb(message: 'bread');
      eventUser = SentryUser(id: '987');
      eventCrumbs = [Breadcrumb(message: 'bread')];
      event = SentryEvent(
        level: SentryLevel.warning,
        transaction: eventTransaction,
        user: eventUser,
        fingerprint: eventFingerprint,
        breadcrumbs: eventCrumbs,
      );
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

      event.user = SentryUser(id: '123', username: 'foo bar');
      await client.captureEvent(event, scope: scope);

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

      event.user = SentryUser(
        id: 'id',
        data: {
          'foo': 'this bar is more important',
          'event': 'Really important event'
        },
      );
      await client.captureEvent(event, scope: scope);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.user?.data?['foo'], 'this bar is more important');
      expect(capturedEvent.user?.data?['bar'], 'foo');
      expect(capturedEvent.user?.data?['event'], 'Really important event');
    });
  });

  group('SentryClient: user & user ip', () {
    late Fixture fixture;
    late SentryUser fakeUser;

    setUp(() {
      fixture = Fixture();
      fakeUser = getFakeUser();
    });

    test('event has no user and sendDefaultPii = true', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final fakeEvent = SentryEvent();
      expect(fakeEvent.user, isNull);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, defaultIpAddress);
    });

    test('event has no user and sendDefaultPii = false', () async {
      final client = fixture.getSut(sendDefaultPii: false);
      var fakeEvent = SentryEvent();
      expect(fakeEvent.user, isNull);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNull);
    });

    test('event has a user with IP address', () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final fakeEvent = getFakeEvent();

      expect(fakeEvent.user?.ipAddress, isNotNull);
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

    test('event has a user without IP address and sendDefaultPii = true',
        () async {
      final client = fixture.getSut(sendDefaultPii: true);
      final fakeEvent = getFakeEvent();
      fakeEvent.user = fakeUser;

      expect(fakeEvent.user?.ipAddress, isNull);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, defaultIpAddress);
      expect(capturedEvent.user?.id, fakeUser.id);
      expect(capturedEvent.user?.email, fakeUser.email);
    });

    test('event has a user without IP address and sendDefaultPii = false',
        () async {
      final client = fixture.getSut(sendDefaultPii: false);
      final fakeEvent = getFakeEvent();
      fakeEvent.user = fakeUser;

      expect(fakeEvent.user?.ipAddress, isNull);

      await client.captureEvent(fakeEvent);

      final capturedEnvelope = fixture.transport.envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(fixture.transport.envelopes.length, 1);
      expect(capturedEvent.user, isNotNull);
      expect(capturedEvent.user?.ipAddress, isNull);
      expect(capturedEvent.user?.id, fakeUser.id);
      expect(capturedEvent.user?.email, fakeUser.email);
    });
  });

  group('SentryClient sampling', () {
    late Fixture fixture;
    late SentryEvent fakeEvent;

    setUp(() {
      fixture = Fixture();
      fakeEvent = getFakeEvent();
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
      final beforeSendTransactionCallback =
          (SentryTransaction event, Hint hint) {
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
    late SentryEvent fakeEvent;

    setUp(() {
      fixture = Fixture();
      fakeEvent = getFakeEvent();
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
    late SentryEvent fakeEvent;

    setUp(() {
      fixture = Fixture();
      fakeEvent = getFakeEvent();
      fixture.options.addEventProcessor(FunctionEventProcessor((event, hint) {
        event.tags = {'theme': 'material'};
        // ignore: deprecated_member_use_from_same_package
        event.extra?['host'] = '0.0.0.1';
        event.modules?.addAll({'core': '1.0'});
        event.breadcrumbs?.add(Breadcrumb(message: 'processor crumb'));
        event.fingerprint?.add('process');
        event.sdk?.addIntegration('testIntegration');
        event.sdk?.addPackage('test-pkg', '1.0');

        return event;
      }));
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

    test('should cap feedback messages to max 4096 characters', () async {
      final client = fixture.getSut();
      final feedback = fixture.fakeFeedback();
      feedback.message = 'a' * 4096 + 'b' * 4096;
      await client.captureFeedback(feedback);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      expect(capturedEvent.contexts.feedback?.message, 'a' * 4096);
    });
  });

  group('SentryClient telemetryProcessor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('sets default telemetry processor when client is initialized', () {
      expect(fixture.options.telemetryProcessor, isA<NoOpTelemetryProcessor>());

      fixture.getSut();

      expect(
          fixture.options.telemetryProcessor, isA<DefaultTelemetryProcessor>());
    });
  });

  group('SentryClient captureLog', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    SentryLog givenLog() {
      return SentryLog(
        timestamp: DateTime.now(),
        traceId: SentryId.newId(),
        level: SentryLogLevel.info,
        body: 'test',
        attributes: {
          'attribute': SentryAttribute.string('value'),
        },
      );
    }

    test('sets log batcher on options when logs are enabled', () async {
      expect(fixture.options.logBatcher is NoopLogBatcher, true);

      fixture.options.enableLogs = true;
      fixture.getSut();

      expect(fixture.options.logBatcher is NoopLogBatcher, false);
    });

    test('disabled by default', () async {
      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();

      await client.captureLog(log);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls, isEmpty);
    });

    test('should capture logs as envelope', () async {
      fixture.options.enableLogs = true;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();

      await client.captureLog(log);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);

      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(capturedLog.traceId, log.traceId);
      expect(capturedLog.level, log.level);
      expect(capturedLog.body, log.body);
      expect(capturedLog.attributes['attribute']?.value,
          log.attributes['attribute']?.value);
    });

    test('should add additional info to attributes', () async {
      fixture.options.enableLogs = true;
      fixture.options.environment = 'test-environment';
      fixture.options.release = 'test-release';

      final log = givenLog();

      final scope = Scope(fixture.options);
      final span = MockSpan();
      scope.span = span;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      await client.captureLog(log, scope: scope);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(
        capturedLog.attributes['sentry.sdk.name']?.value,
        fixture.options.sdk.name,
      );
      expect(
        capturedLog.attributes['sentry.sdk.name']?.type,
        'string',
      );
      expect(
        capturedLog.attributes['sentry.sdk.version']?.value,
        fixture.options.sdk.version,
      );
      expect(
        capturedLog.attributes['sentry.sdk.version']?.type,
        'string',
      );
      expect(
        capturedLog.attributes['sentry.environment']?.value,
        fixture.options.environment,
      );
      expect(
        capturedLog.attributes['sentry.environment']?.type,
        'string',
      );
      expect(
        capturedLog.attributes['sentry.release']?.value,
        fixture.options.release,
      );
      expect(
        capturedLog.attributes['sentry.release']?.type,
        'string',
      );
      expect(
        capturedLog.attributes['sentry.trace.parent_span_id']?.value,
        span.context.spanId.toString(),
      );
      expect(
        capturedLog.attributes['sentry.trace.parent_span_id']?.type,
        'string',
      );
    });

    test('should use attributes from given scope', () async {
      fixture.options.enableLogs = true;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();
      final log = givenLog();

      final scope = Scope(fixture.options);
      scope.setAttributes({'from_scope': SentryAttribute.int(12)});

      await client.captureLog(log, scope: scope);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;
      expect(capturedLog.attributes['from_scope']?.value, 12);
    });

    test('per-log attributes override scope on same key', () async {
      fixture.options.enableLogs = true;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();
      final log = givenLog();

      final scope = Scope(fixture.options);
      scope.setAttributes({
        'overridden': SentryAttribute.string('fromScope'),
        'kept': SentryAttribute.bool(true),
      });

      log.attributes['overridden'] = SentryAttribute.string('fromLog');
      log.attributes['logOnly'] = SentryAttribute.double(1.23);

      await client.captureLog(log, scope: scope);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final captured = mockLogBatcher.addLogCalls.first;

      expect(captured.attributes['overridden']?.value, 'fromLog');
      expect(captured.attributes['kept']?.value, true);
      expect(captured.attributes['logOnly']?.type, 'double');
    });

    test('should add user info to attributes', () async {
      fixture.options.enableLogs = true;

      final log = givenLog();
      final scope = Scope(fixture.options);
      final user = SentryUser(
        id: '123',
        email: 'test@test.com',
        name: 'test-name',
      );
      await scope.setUser(user);

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      await client.captureLog(log, scope: scope);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(
        capturedLog.attributes['user.id']?.value,
        user.id,
      );
      expect(
        capturedLog.attributes['user.id']?.type,
        'string',
      );

      expect(
        capturedLog.attributes['user.name']?.value,
        user.name,
      );
      expect(
        capturedLog.attributes['user.name']?.type,
        'string',
      );

      expect(
        capturedLog.attributes['user.email']?.value,
        user.email,
      );
      expect(
        capturedLog.attributes['user.email']?.type,
        'string',
      );
    });

    test('should set trace id from propagation context', () async {
      fixture.options.enableLogs = true;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();
      final scope = Scope(fixture.options);

      await client.captureLog(log, scope: scope);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(capturedLog.traceId, scope.propagationContext.traceId);
    });

    test(
        '$BeforeSendLogCallback returning null drops the log and record it as lost',
        () async {
      fixture.options.enableLogs = true;
      fixture.options.beforeSendLog = (log) => null;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();

      await client.captureLog(log);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 0);

      expect(
        fixture.recorder.discardedEvents.first.reason,
        DiscardReason.beforeSend,
      );
      expect(
        fixture.recorder.discardedEvents.first.category,
        DataCategory.logItem,
      );
    });

    test('$BeforeSendLogCallback returning a log modifies it', () async {
      fixture.options.enableLogs = true;
      fixture.options.beforeSendLog = (log) {
        log.body = 'modified';
        return log;
      };

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();

      await client.captureLog(log);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(capturedLog.body, 'modified');
    });

    test('$BeforeSendLogCallback returning a log async modifies it', () async {
      fixture.options.enableLogs = true;
      fixture.options.beforeSendLog = (log) async {
        await Future.delayed(Duration(milliseconds: 100));
        log.body = 'modified';
        return log;
      };

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();

      await client.captureLog(log);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(capturedLog.body, 'modified');
    });

    test('$BeforeSendLogCallback throwing is caught', () async {
      fixture.options.enableLogs = true;
      fixture.options.automatedTestMode = false;

      fixture.options.beforeSendLog = (log) {
        throw Exception('test');
      };

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      final log = givenLog();
      await client.captureLog(log);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(capturedLog.body, 'test');
    });

    test('OnBeforeCaptureLog lifecycle event is called', () async {
      fixture.options.enableLogs = true;
      fixture.options.environment = 'test-environment';
      fixture.options.release = 'test-release';

      final log = givenLog();

      final scope = Scope(fixture.options);
      final span = MockSpan();
      scope.span = span;

      final client = fixture.getSut();
      fixture.options.logBatcher = MockLogBatcher();

      fixture.options.lifecycleRegistry
          .registerCallback<OnBeforeCaptureLog>((event) {
        event.log.attributes['test'] = SentryAttribute.string('test-value');
      });

      await client.captureLog(log, scope: scope);

      final mockLogBatcher = fixture.options.logBatcher as MockLogBatcher;
      expect(mockLogBatcher.addLogCalls.length, 1);
      final capturedLog = mockLogBatcher.addLogCalls.first;

      expect(capturedLog.attributes['test']?.value, "test-value");
      expect(capturedLog.attributes['test']?.type, 'string');
    });
  });

  group('SentryClient captures envelope', () {
    late Fixture fixture;
    final fakeEnvelope = getFakeEnvelope();

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

  group('ClientReportTransport', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('set on options on init', () async {
      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
      );

      expect(fixture.options.transport is ClientReportTransport, true);
    });

    test('has rateLimiter with http transport', () async {
      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
        transport: NoOpTransport(), // this will set http transport
      );

      expect(fixture.options.transport is ClientReportTransport, true);
      final crt = fixture.options.transport as ClientReportTransport;
      expect(crt.rateLimiter, isNotNull);
    });

    test('does not have rateLimiter without http transport', () async {
      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
        transport: MockTransport(),
      );

      expect(fixture.options.transport is ClientReportTransport, true);
      final crt = fixture.options.transport as ClientReportTransport;
      expect(crt.rateLimiter, isNull);
    });
  });

  group('ClientReportRecorder', () {
    late Fixture fixture;
    late SentryEvent fakeEvent;

    setUp(() {
      fixture = Fixture();
      fakeEvent = getFakeEvent();
    });

    test('recorder is not noop if client reports are enabled', () async {
      fixture.options.sendClientReports = true;

      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
      );

      expect(fixture.options.recorder is NoOpClientReportRecorder, false);
    });

    test('recorder is noop if client reports are disabled', () {
      fixture.options.sendClientReports = false;

      fixture.getSut(
        eventProcessor: DropAllEventProcessor(),
        provideMockRecorder: false,
      );

      expect(fixture.options.recorder is NoOpClientReportRecorder, true);
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

    test('record event processor dropping feedback', () async {
      final client = fixture.getSut(eventProcessor: DropAllEventProcessor());
      final feedback = fixture.fakeFeedback();
      await client.captureFeedback(feedback);

      expect(fixture.recorder.discardedEvents.first.category,
          DataCategory.feedback);
      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.eventProcessor);
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

      fixture.options.beforeSendTransaction = (transaction, hint) {
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

      fixture.options.beforeSendTransaction = (transaction, hint) {
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

    test('record beforeSend dropping feedback', () async {
      final client = fixture.getSut();

      fixture.options.beforeSendFeedback = fixture.droppingBeforeSend;

      final feedback = fixture.fakeFeedback();
      await client.captureFeedback(feedback);

      expect(fixture.recorder.discardedEvents.first.reason,
          DiscardReason.beforeSend);
      expect(fixture.recorder.discardedEvents.first.category,
          DataCategory.feedback);
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

    test('record sample rate not dropping feedback', () async {
      final client = fixture.getSut(sampleRate: 0.0);

      await client.captureFeedback(fixture.fakeFeedback());

      expect(fixture.recorder.discardedEvents.isEmpty, true);
    });
  });

  group('Spotlight', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
        'Spotlight enabled should not set transport to SpotlightHttpTransport on iOS',
        () async {
      fixture.options.platform = MockPlatform.iOS();
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isFalse);
    });

    test(
        'Spotlight enabled should not set transport to SpotlightHttpTransport on macOS',
        () async {
      fixture.options.platform = MockPlatform.macOS();
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isFalse);
    });

    test(
        'Spotlight enabled should not set transport to SpotlightHttpTransport on Android',
        () async {
      fixture.options.platform = MockPlatform.android();
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isFalse);
    });

    test(
        'Spotlight enabled should set transport to SpotlightHttpTransport on Web',
        () async {
      fixture.options.platform = MockPlatform(isWeb: true);
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isTrue);
    });

    test(
        'Spotlight enabled should set transport to SpotlightHttpTransport on Linux',
        () async {
      fixture.options.platform = MockPlatform.linux();
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isTrue);
    });

    test(
        'Spotlight enabled should set transport to SpotlightHttpTransport on Windows',
        () async {
      fixture.options.platform = MockPlatform.windows();
      fixture.options.spotlight = Spotlight(enabled: true);
      fixture.getSut();

      expect(fixture.options.transport is SpotlightHttpTransport, isTrue);
    });
  });

  group('trace context', () {
    late Fixture fixture;
    late SentryEvent fakeEvent;

    setUp(() {
      fixture = Fixture();
      fakeEvent = getFakeEvent();
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
    late SentryEvent fakeEvent;

    setUp(() {
      fixture = Fixture();
      fakeEvent = getFakeEvent();
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

    test('captureTransaction hint passed to beforeSendTransaction', () async {
      final sut = fixture.getSut();

      final hint = Hint();
      final transaction = SentryTransaction(fixture.tracer);

      fixture.options.beforeSendTransaction = (bsTransaction, bsHint) async {
        expect(hint, bsHint);
        return bsTransaction;
      };

      await sut.captureTransaction(transaction, hint: hint);
    });

    test('captureTransaction hint passed to event processors', () async {
      final hint = Hint();

      final eventProcessor = FunctionEventProcessor((event, epHint) {
        expect(epHint, hint);
        return event;
      });
      final sut = fixture.getSut(eventProcessor: eventProcessor);

      final transaction = SentryTransaction(fixture.tracer);
      await sut.captureTransaction(transaction, hint: hint);
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
        (element) => element.header.type == SentryItemType.attachment,
      );
      expect(attachmentItem, isNull);
    });

    test(
        'null stack trace marked in hint & sentry frames removed from thread stackTrace',
        () async {
      final beforeSendCallback = (SentryEvent event, Hint hint) {
        expect(hint.get(TypeCheckHint.currentStackTrace), isTrue);
        return event;
      };
      final client = fixture.getSut(
          beforeSend: beforeSendCallback, attachStacktrace: true);
      await client.captureEvent(fakeEvent);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      final sentryFramesCount = capturedEvent.threads?[0].stacktrace!.frames
          .where((frame) => frame.package == 'sentry')
          .length;

      expect(sentryFramesCount, 0);
    });

    test(
        'empty stack trace marked in hint & sentry frames removed from thread stackTrace',
        () async {
      final beforeSendCallback = (SentryEvent event, Hint hint) {
        expect(hint.get(TypeCheckHint.currentStackTrace), isTrue);
        return event;
      };
      final client = fixture.getSut(
          beforeSend: beforeSendCallback, attachStacktrace: true);
      await client.captureEvent(fakeEvent, stackTrace: StackTrace.empty);

      final capturedEnvelope = (fixture.transport).envelopes.first;
      final capturedEvent = await eventFromEnvelope(capturedEnvelope);

      final sentryFramesCount = capturedEvent.threads?[0].stacktrace!.frames
          .where((frame) => frame.package == 'sentry')
          .length;

      expect(sentryFramesCount, 0);
    });

    test('non-null stack trace not marked in hint', () async {
      final beforeSendCallback = (SentryEvent event, Hint hint) {
        expect(hint.get(TypeCheckHint.currentStackTrace), isNull);
        return event;
      };
      final client = fixture.getSut(
          beforeSend: beforeSendCallback, attachStacktrace: true);
      await client.captureEvent(fakeEvent, stackTrace: StackTrace.current);
    });
  });

  group('SentryClient close', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('waits for log batcher flush before closing http client', () async {
      // Create a mock HTTP client that tracks when close is called
      final mockHttpClient = MockHttpClient();
      fixture.options.httpClient = mockHttpClient;

      fixture.options.enableLogs = true;
      final client = fixture.getSut();

      // Create a completer to control when flush completes
      final flushCompleter = Completer<void>();
      bool flushStarted = false;

      // Create a mock log batcher with async flush
      final mockLogBatcher = MockLogBatcherWithAsyncFlush(
        onFlush: () async {
          flushStarted = true;
          // Wait for the completer to complete
          await flushCompleter.future;
        },
      );
      fixture.options.logBatcher = mockLogBatcher;

      // Start close() in the background
      final closeFuture = client.close();

      // Wait a bit longer to ensure flush has started
      await Future.delayed(Duration(milliseconds: 50));

      // Verify flush has started but HTTP client is not closed yet
      expect(flushStarted, true, reason: 'Flush should have started');
      verifyNever(mockHttpClient.close());

      // Complete the flush
      flushCompleter.complete();

      // Wait for close to complete
      await closeFuture;

      // Now verify HTTP client was closed
      verify(mockHttpClient.close()).called(1);
    });
  });
}

Future<SentryEvent> eventFromEnvelope(SentryEnvelope envelope) async {
  final data = await envelope.items.first.dataFactory();
  final utf8Data = utf8.decode(data);
  final envelopeItemJson = jsonDecode(utf8Data);
  return SentryEvent.fromJson(envelopeItemJson as Map<String, dynamic>);
}

Future<Map<String, dynamic>> transactionFromEnvelope(
    SentryEnvelope envelope) async {
  final data = await envelope.items.first.dataFactory();
  final utf8Data = utf8.decode(data);
  final envelopeItemJson = jsonDecode(utf8Data);
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
  Hint hint,
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
  SentryEvent event,
  Hint hint,
) async {
  await Future.delayed(Duration(milliseconds: 200));
  return null;
}

SentryEvent? beforeSendFeedbackCallback(SentryEvent event, Hint hint) {
  event.tags = {'theme': 'material'};
  return event;
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
  SentryTransaction transaction,
  Hint hint,
) {
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

  final options = defaultTestOptions()
    ..platform = MockPlatform.iOS()
    ..groupExceptions = true;

  late SentryTransactionContext _context;
  late SentryTracer tracer;

  SentryLevel? loggedLevel;
  Object? loggedException;

  SentryClient getSut({
    bool sendDefaultPii = false,
    bool attachStacktrace = true,
    bool attachThreads = false,
    double? sampleRate,
    BeforeSendCallback? beforeSend,
    BeforeSendTransactionCallback? beforeSendTransaction,
    BeforeSendCallback? beforeSendFeedback,
    EventProcessor? eventProcessor,
    bool provideMockRecorder = true,
    bool debug = false,
    Transport? transport,
  }) {
    options.tracesSampleRate = 1.0;
    options.sendDefaultPii = sendDefaultPii;
    options.attachStacktrace = attachStacktrace;
    options.attachThreads = attachThreads;
    options.sampleRate = sampleRate;
    options.beforeSend = beforeSend;
    options.beforeSendTransaction = beforeSendTransaction;
    options.beforeSendFeedback = beforeSendFeedback;
    options.debug = debug;
    options.log = mockLogger;

    if (eventProcessor != null) {
      options.addEventProcessor(eventProcessor);
    }

    // Internally also creates a SentryClient instance
    final hub = Hub(options);
    _context = SentryTransactionContext(
      'name',
      'op',
    );
    tracer = SentryTracer(_context, hub);

    // Reset transport
    options.transport = transport ?? this.transport;

    // Again create SentryClient instance
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

class MockHttpClient extends Mock implements http.Client {}

class MockLogBatcherWithAsyncFlush implements SentryLogBatcher {
  final Future<void> Function() onFlush;
  final addLogCalls = <SentryLog>[];

  MockLogBatcherWithAsyncFlush({required this.onFlush});

  @override
  void addLog(SentryLog log) {
    addLogCalls.add(log);
  }

  @override
  FutureOr<void> flush() async {
    await onFlush();
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
    return ExceptionCause(error.cause, error.stackTrace, source: "cause");
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
