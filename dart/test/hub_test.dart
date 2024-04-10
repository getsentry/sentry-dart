import 'package:collection/collection.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks.mocks.dart';
import 'mocks/mock_client_report_recorder.dart';
import 'mocks/mock_sentry_client.dart';

void main() {
  bool scopeEquals(Scope? a, Scope b) {
    return identical(a, b) ||
        a!.level == b.level &&
            a.transaction == b.transaction &&
            a.user == b.user &&
            IterableEquality().equals(a.fingerprint, b.fingerprint) &&
            IterableEquality().equals(a.breadcrumbs, b.breadcrumbs) &&
            MapEquality().equals(a.tags, b.tags) &&
            MapEquality().equals(a.extra, b.extra);
  }

  group('Hub instantiation', () {
    test('should instantiate with a dsn', () {
      final hub = Hub(SentryOptions(dsn: fakeDsn));
      expect(hub.isEnabled, true);
    });
  });

  group('Hub captures', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test(
      'should capture event with the default scope',
      () async {
        final hub = fixture.getSut();
        await hub.captureEvent(fakeEvent);

        var scope = fixture.client.captureEventCalls.first.scope;

        expect(
          fixture.client.captureEventCalls.first.event,
          fakeEvent,
        );

        expect(scopeEquals(scope, Scope(fixture.options)), true);
      },
    );

    test('should capture exception', () async {
      final hub = fixture.getSut();
      await hub.captureException(fakeException);

      expect(fixture.client.captureEventCalls.length, 1);
      expect(
        fixture.client.captureEventCalls.first.event.throwable,
        fakeException,
      );
      expect(fixture.client.captureEventCalls.first.scope, isNotNull);
    });

    test('should capture message', () async {
      final hub = fixture.getSut();
      await hub.captureMessage(
        fakeMessage.formatted,
        level: SentryLevel.warning,
      );

      expect(fixture.client.captureMessageCalls.length, 1);
      expect(fixture.client.captureMessageCalls.first.formatted,
          fakeMessage.formatted);
      expect(
          fixture.client.captureMessageCalls.first.level, SentryLevel.warning);
      expect(fixture.client.captureMessageCalls.first.scope, isNotNull);
    });

    test('should capture metrics', () async {
      final hub = fixture.getSut();
      await hub.captureMetrics(fakeMetrics);

      expect(fixture.client.captureMetricsCalls.length, 1);
      expect(
        fixture.client.captureMetricsCalls.first.values,
        [
          [fakeMetric],
          [fakeMetric, fakeMetric2],
          [fakeMetric, fakeMetric3, fakeMetric4],
        ],
      );
    });

    test('should save the lastEventId', () async {
      final hub = fixture.getSut();
      final event = SentryEvent();
      final eventId = event.eventId;
      final returnedId = await hub.captureEvent(event);
      expect(eventId.toString(), returnedId.toString());
    });

    test('capture event should assign trace context', () async {
      final hub = fixture.getSut();

      final event = SentryEvent(throwable: fakeException);
      final span = NoOpSentrySpan();
      hub.setSpanContext(fakeException, span, 'test');

      await hub.captureEvent(event);
      final capturedEvent = fixture.client.captureEventCalls.first;

      expect(capturedEvent.event.transaction, 'test');
      expect(capturedEvent.event.contexts.trace, isNotNull);
    });

    test('capture exception should assign trace context', () async {
      final hub = fixture.getSut();

      final span = NoOpSentrySpan();
      hub.setSpanContext(fakeException, span, 'test');

      await hub.captureException(fakeException);
      final capturedEvent = fixture.client.captureEventCalls.first;

      expect(capturedEvent.event.transaction, 'test');
      expect(capturedEvent.event.contexts.trace, isNotNull);
    });

    test('capture exception should assign sampled trace context', () async {
      final hub = fixture.getSut();

      final span = SentrySpan(
        fixture.tracer,
        fixture._context,
        hub,
        samplingDecision: fixture._context.samplingDecision,
      );
      hub.setSpanContext(fakeException, span, 'test');

      await hub.captureException(fakeException);
      final capturedEvent = fixture.client.captureEventCalls.first;

      expect(capturedEvent.event.contexts.trace, isNotNull);
      expect(capturedEvent.event.contexts.trace!.sampled, isTrue);
    });

    test('Expando does not throw when exception type is not supported',
        () async {
      final hub = fixture.getSut();

      try {
        throw 'string error';
      } catch (exception, _) {
        final event = SentryEvent(throwable: exception);
        final span = NoOpSentrySpan();
        hub.setSpanContext(exception, span, 'test');

        await hub.captureEvent(event);
      }

      final capturedEvent = fixture.client.captureEventCalls.first;

      expect(capturedEvent.event.transaction, 'test');
      expect(capturedEvent.event.contexts.trace, isNotNull);
    });
  });

  group('Hub transactions', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('start transaction with given name, op, desc and start time',
        () async {
      final hub = fixture.getSut();
      final startTime = DateTime.now();

      final tr = hub.startTransaction(
        'name',
        'op',
        startTimestamp: startTime,
        description: 'desc',
      );

      expect(tr.context.operation, 'op');
      expect(tr.context.description, 'desc');
      expect(tr.startTimestamp.isAtSameMomentAs(startTime), true);
      expect((tr as SentryTracer).name, 'name');
      expect(tr.origin, SentryTraceOrigins.manual);
    });

    test('start transaction binds span to the scope', () async {
      final hub = fixture.getSut();

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
        bindToScope: true,
      );

      await hub.configureScope((Scope scope) {
        expect(scope.span, tr);
      });
    });

    test('start transaction does not bind span to the scope', () async {
      final hub = fixture.getSut();

      hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      await hub.configureScope((Scope scope) {
        expect(scope.span, isNull);
      });
    });

    test('start transaction samples the transaction', () async {
      final hub = fixture.getSut();

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      expect(tr.samplingDecision?.sampled, true);
    });

    test('start transaction does not sample the transaction', () async {
      final hub = fixture.getSut(tracesSampleRate: 0.0);

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      expect(tr.samplingDecision?.sampled, false);
    });

    test('start transaction runs callback with customSamplingContext',
        () async {
      double? mySampling(SentrySamplingContext samplingContext) {
        expect(samplingContext.customSamplingContext['test'], '1');
        return 0.0;
      }

      final hub = fixture.getSut(
        tracesSampleRate: null,
        tracesSampler: mySampling,
      );
      final map = {'test': '1'};

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
        customSamplingContext: map,
      );

      expect(tr.samplingDecision?.sampled, false);
    });

    test('start transaction respects given sampled', () async {
      final hub = fixture.getSut();

      final tr = hub.startTransactionWithContext(
        SentryTransactionContext('name', 'op',
            samplingDecision: SentryTracesSamplingDecision(false)),
      );

      expect(tr.samplingDecision?.sampled, false);
    });

    test('start transaction with context sets trace origin fallback', () async {
      final hub = fixture.getSut();
      final tr = hub.startTransactionWithContext(
        SentryTransactionContext('name', 'op'),
      );
      expect(tr.origin, SentryTraceOrigins.manual);
    });

    test('start transaction with context keeps origin', () async {
      final hub = fixture.getSut();
      final tr = hub.startTransactionWithContext(
        SentryTransactionContext('name', 'op', origin: 'auto.navigation.test'),
      );
      expect(tr.origin, 'auto.navigation.test');
    });

    test('start transaction return NoOp if performance is disabled', () async {
      final hub = fixture.getSut(tracesSampleRate: null);

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      expect(tr, NoOpSentrySpan());
    });

    test('get span returns span bound to the scope', () async {
      final hub = fixture.getSut();

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
        bindToScope: true,
      );

      expect(hub.getSpan(), tr);
    });

    test('get span does not return span if not bound to the scope', () async {
      final hub = fixture.getSut();

      hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      expect(hub.getSpan(), isNull);
    });

    test('get span does not return span if tracing is disabled', () async {
      final hub = fixture.getSut(tracesSampleRate: null);

      hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      expect(hub.getSpan(), isNull);
    });

    test('transaction isnt captured if not sampled', () async {
      final hub = fixture.getSut(sampled: false);

      var tr = SentryTransaction(fixture.tracer);
      final id = await hub.captureTransaction(tr);

      expect(id, SentryId.empty());
    });

    test('transaction isnt captured if tracing is disabled', () async {
      final hub = fixture.getSut(tracesSampleRate: null);

      var tr = SentryTransaction(fixture.tracer);
      final id = await hub.captureTransaction(tr);

      expect(id, SentryId.empty());
    });

    test('transaction is captured', () async {
      final hub = fixture.getSut();

      var tr = SentryTransaction(fixture.tracer);
      final id = await hub.captureTransaction(tr);

      expect(id, tr.eventId);
      expect(fixture.client.captureTransactionCalls.length, 1);
    });

    test('transaction is captured with traceContext', () async {
      final hub = fixture.getSut();

      var tr = SentryTransaction(fixture.tracer);
      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${tr.eventId}',
        'public_key': '123',
      });
      final id = await hub.captureTransaction(tr, traceContext: context);

      expect(id, tr.eventId);
      expect(fixture.client.captureTransactionCalls.length, 1);
      expect(
          fixture.client.captureTransactionCalls.first.traceContext, context);
    });
  });

  group('Hub profiles', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('profiler is not started by default', () async {
      final hub = fixture.getSut();
      final tr = hub.startTransaction('name', 'op');
      expect(tr, isA<SentryTracer>());
      expect((tr as SentryTracer).profiler, isNull);
    });

    test('profiler is started according to the sampling rate', () async {
      final hub = fixture.getSut();
      final factory = MockSentryProfilerFactory();
      when(factory.startProfiler(fixture._context))
          .thenReturn(MockSentryProfiler());
      hub.profilerFactory = factory;

      var tr = hub.startTransactionWithContext(fixture._context);
      expect((tr as SentryTracer).profiler, isNull);
      verifyZeroInteractions(factory);

      hub.options.profilesSampleRate = 1.0;
      tr = hub.startTransactionWithContext(fixture._context);
      expect((tr as SentryTracer).profiler, isNotNull);
      verify(factory.startProfiler(fixture._context)).called(1);
    });

    test('profiler.finish() is called', () async {
      final hub = fixture.getSut();
      final factory = MockSentryProfilerFactory();
      final profiler = MockSentryProfiler();
      final expected = MockSentryProfileInfo();
      when(factory.startProfiler(fixture._context)).thenReturn(profiler);
      when(profiler.finishFor(any)).thenAnswer((_) async => expected);

      hub.profilerFactory = factory;
      hub.options.profilesSampleRate = 1.0;
      final tr = hub.startTransactionWithContext(fixture._context);
      await tr.finish();
      verify(profiler.finishFor(any)).called(1);
      verify(profiler.dispose()).called(1);
    });

    test('profiler.dispose() is called even if not captured', () async {
      final hub = fixture.getSut();
      final factory = MockSentryProfilerFactory();
      final profiler = MockSentryProfiler();
      final expected = MockSentryProfileInfo();
      when(factory.startProfiler(fixture._context)).thenReturn(profiler);
      when(profiler.finishFor(any)).thenAnswer((_) async => expected);

      hub.profilerFactory = factory;
      hub.options.profilesSampleRate = 1.0;
      final tr = hub.startTransactionWithContext(fixture._context);
      await tr.finish(status: SpanStatus.aborted());
      verify(profiler.dispose()).called(1);
      verifyNever(profiler.finishFor(any));
    });
  });

  group('Hub scope', () {
    var hub = Hub(SentryOptions(dsn: fakeDsn));
    var client = MockSentryClient();

    setUp(() {
      hub = Hub(SentryOptions(dsn: fakeDsn));
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('returns scope', () async {
      final scope = hub.scope;
      expect(scope, isNotNull);
    });

    test('should configure its scope', () async {
      await hub.configureScope((Scope scope) {
        scope
          ..level = SentryLevel.debug
          ..fingerprint = ['1', '2'];

        scope.setUser(fakeUser);
      });
      await hub.captureEvent(fakeEvent);

      expect(client.captureEventCalls.isNotEmpty, true);
      expect(client.captureEventCalls.first.event, fakeEvent);
      expect(client.captureEventCalls.first.scope, isNotNull);
      final scope = client.captureEventCalls.first.scope;

      final otherScope = Scope(SentryOptions(dsn: fakeDsn))
        ..level = SentryLevel.debug
        ..fingerprint = ['1', '2'];

      await otherScope.setUser(fakeUser);

      expect(
        scopeEquals(
          scope,
          otherScope,
        ),
        true,
      );
    });

    test('should configure scope async', () async {
      await hub.configureScope((Scope scope) async {
        await Future.delayed(Duration(milliseconds: 10));
        return scope.setUser(fakeUser);
      });

      await hub.captureEvent(fakeEvent);

      final scope = client.captureEventCalls.first.scope;
      final otherScope = Scope(SentryOptions(dsn: fakeDsn));
      await otherScope.setUser(fakeUser);

      expect(
          scopeEquals(
            scope,
            otherScope,
          ),
          true);
    });

    test('should add breadcrumb to current Scope', () async {
      await hub.configureScope((Scope scope) {
        expect(0, scope.breadcrumbs.length);
      });
      await hub.addBreadcrumb(Breadcrumb(message: 'test'));
      await hub.configureScope((Scope scope) {
        expect(1, scope.breadcrumbs.length);
        expect('test', scope.breadcrumbs.first.message);
      });
    });
  });

  group('Hub scope callback', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('captureEvent should handle thrown error in scope callback', () async {
      final hub = fixture.getSut(debug: true);
      final scopeCallbackException = Exception('error in scope callback');

      ScopeCallback scopeCallback = (Scope scope) {
        throw scopeCallbackException;
      };

      await hub.captureEvent(fakeEvent, withScope: scopeCallback);

      expect(fixture.loggedException, scopeCallbackException);
      expect(fixture.loggedLevel, SentryLevel.error);
    });

    test('captureException should handle thrown error in scope callback',
        () async {
      final hub = fixture.getSut(debug: true);
      final scopeCallbackException = Exception('error in scope callback');

      ScopeCallback scopeCallback = (Scope scope) {
        throw scopeCallbackException;
      };

      final exception = Exception("captured exception");
      await hub.captureException(exception, withScope: scopeCallback);

      expect(fixture.loggedException, scopeCallbackException);
      expect(fixture.loggedLevel, SentryLevel.error);
    });

    test('captureMessage should handle thrown error in scope callback',
        () async {
      final hub = fixture.getSut(debug: true);
      final scopeCallbackException = Exception('error in scope callback');

      ScopeCallback scopeCallback = (Scope scope) {
        throw scopeCallbackException;
      };

      await hub.captureMessage("captured message", withScope: scopeCallback);

      expect(fixture.loggedException, scopeCallbackException);
      expect(fixture.loggedLevel, SentryLevel.error);
    });
  });

  group('Hub Client', () {
    late Hub hub;
    late SentryClient client;
    SentryOptions options;

    setUp(() {
      options = SentryOptions(dsn: fakeDsn);
      hub = Hub(options);
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should bind a new client', () async {
      final client2 = MockSentryClient();
      hub.bindClient(client2);
      await hub.captureEvent(fakeEvent);
      expect(client2.captureEventCalls.length, 1);
      expect(client2.captureEventCalls.first.event, fakeEvent);
      expect(client2.captureEventCalls.first.scope, isNotNull);
    });

    test('should close its client', () async {
      await hub.close();

      expect(hub.isEnabled, false);
      expect((client as MockSentryClient).closeCalls, 1);
    });
  });

  test('clones', () {
    // TODO I'm not sure how to test it
    // could we set [hub.stack] as @visibleForTesting ?
  });

  group('Hub withScope', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('captureEvent should create a new scope', () async {
      final hub = fixture.getSut();
      await hub.captureEvent(SentryEvent());
      await hub.captureEvent(SentryEvent(), withScope: (scope) async {
        await scope.setUser(SentryUser(id: 'foo bar'));
      });
      await hub.captureEvent(SentryEvent());

      var calls = fixture.client.captureEventCalls;
      expect(calls.length, 3);
      expect(calls[0].scope?.user, isNull);
      expect(calls[1].scope?.user?.id, 'foo bar');
      expect(calls[2].scope?.user, isNull);
    });

    test('captureException should create a new scope', () async {
      final hub = fixture.getSut();
      await hub.captureException(Exception('0'));
      await hub.captureException(Exception('1'), withScope: (scope) async {
        await scope.setUser(SentryUser(id: 'foo bar'));
      });
      await hub.captureException(Exception('2'));

      var calls = fixture.client.captureEventCalls;
      expect(calls.length, 3);
      expect(calls[0].scope?.user, isNull);
      expect(calls[0].event.throwable?.toString(), 'Exception: 0');

      expect(calls[1].scope?.user?.id, 'foo bar');
      expect(calls[1].event.throwable?.toString(), 'Exception: 1');

      expect(calls[2].scope?.user, isNull);
      expect(calls[2].event.throwable?.toString(), 'Exception: 2');
    });

    test('captureMessage should create a new scope', () async {
      final hub = fixture.getSut();
      await hub.captureMessage('foo bar 0');
      await hub.captureMessage('foo bar 1', withScope: (scope) async {
        await scope.setUser(SentryUser(id: 'foo bar'));
      });
      await hub.captureMessage('foo bar 2');

      var calls = fixture.client.captureMessageCalls;
      expect(calls.length, 3);
      expect(calls[0].scope?.user, isNull);
      expect(calls[0].formatted, 'foo bar 0');

      expect(calls[1].scope?.user?.id, 'foo bar');
      expect(calls[1].formatted, 'foo bar 1');

      expect(calls[2].scope?.user, isNull);
      expect(calls[2].formatted, 'foo bar 2');
    });
  });

  group('ClientReportRecorder', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('record sample rate dropping transaction', () async {
      final hub = fixture.getSut(sampled: false);
      var transaction = SentryTransaction(fixture.tracer);

      await hub.captureTransaction(transaction);

      expect(fixture.recorder.reason, DiscardReason.sampleRate);
      expect(fixture.recorder.category, DataCategory.transaction);
    });
  });

  group('Metrics', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('should not capture metrics if enableMetric is false', () async {
      final hub = fixture.getSut(enableMetrics: false, debug: true);
      await hub.captureMetrics(fakeMetrics);

      expect(fixture.client.captureMetricsCalls, isEmpty);
      expect(fixture.loggedMessage,
          'Metrics are disabled and this \'captureMetrics\' call is a no-op.');
    });

    test('should not capture metrics if hub is closed', () async {
      final hub = fixture.getSut(debug: true);
      await hub.close();

      expect(hub.isEnabled, false);
      await hub.captureMetrics(fakeMetrics);
      expect(fixture.loggedMessage,
          'Instance is disabled and this \'captureMetrics\' call is a no-op.');

      expect(fixture.client.captureMetricsCalls, isEmpty);
    });

    test('should not capture metrics if metrics are empty', () async {
      final hub = fixture.getSut(debug: true);
      await hub.captureMetrics({});
      expect(fixture.loggedMessage,
          'Metrics are empty and this \'captureMetrics\' call is a no-op.');

      expect(fixture.client.captureMetricsCalls, isEmpty);
    });
  });
}

class Fixture {
  final client = MockSentryClient();
  final recorder = MockClientReportRecorder();

  final options = SentryOptions(dsn: fakeDsn);
  late SentryTransactionContext _context;
  late SentryTracer tracer;

  SentryLevel? loggedLevel;
  String? loggedMessage;
  Object? loggedException;

  Hub getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool? sampled = true,
    bool enableMetrics = true,
    bool debug = false,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    options.debug = debug;
    options.enableMetrics = enableMetrics;
    options.logger = mockLogger; // Enable logging in DiagnosticsLogger

    final hub = Hub(options);

    // A fully configured context - won't trigger a copy in startTransaction().
    _context = SentryTransactionContext(
      'name',
      'op',
      samplingDecision: SentryTracesSamplingDecision(sampled!),
      origin: SentryTraceOrigins.manual,
    );

    tracer = SentryTracer(_context, hub);

    hub.bindClient(client);
    options.recorder = recorder;

    return hub;
  }

  void mockLogger(
    SentryLevel level,
    String message, {
    String? logger,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    loggedLevel = level;
    loggedMessage = message;
    loggedException = exception;
  }
}
