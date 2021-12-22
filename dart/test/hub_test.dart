import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import 'mocks.dart';
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

      expect(capturedEvent.event.transaction, isNull);
      expect(capturedEvent.event.contexts.trace, isNull);
    });
  });

  group('Hub captures', () {
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
    });

    test('start transaction binds span to the scope', () async {
      final hub = fixture.getSut();

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
        bindToScope: true,
      );

      hub.configureScope((Scope scope) {
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

      hub.configureScope((Scope scope) {
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

      expect(tr.sampled, true);
    });

    test('start transaction does not sample the transaction', () async {
      final hub = fixture.getSut(tracesSampleRate: 0.0);

      final tr = hub.startTransaction(
        'name',
        'op',
        description: 'desc',
      );

      expect(tr.sampled, false);
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

      expect(tr.sampled, false);
    });

    test('start transaction respects given sampled', () async {
      final hub = fixture.getSut();

      final tr = hub.startTransactionWithContext(
        SentryTransactionContext('name', 'op', sampled: false),
      );

      expect(tr.sampled, false);
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
  });

  group('Hub scope', () {
    var hub = Hub(SentryOptions(dsn: fakeDsn));
    var client = MockSentryClient();

    setUp(() {
      hub = Hub(SentryOptions(dsn: fakeDsn));
      client = MockSentryClient();
      hub.bindClient(client);
    });

    test('should configure its scope', () async {
      hub.configureScope((Scope scope) {
        scope
          ..user = fakeUser
          ..level = SentryLevel.debug
          ..fingerprint = ['1', '2'];
      });
      await hub.captureEvent(fakeEvent);

      expect(client.captureEventCalls.isNotEmpty, true);
      expect(client.captureEventCalls.first.event, fakeEvent);
      expect(client.captureEventCalls.first.scope, isNotNull);
      final scope = client.captureEventCalls.first.scope;

      expect(
        scopeEquals(
          scope,
          Scope(SentryOptions(dsn: fakeDsn))
            ..level = SentryLevel.debug
            ..user = fakeUser
            ..fingerprint = ['1', '2'],
        ),
        true,
      );
    });

    test('should add breadcrumb to current Scope', () {
      hub.configureScope((Scope scope) {
        expect(0, scope.breadcrumbs.length);
      });
      hub.addBreadcrumb(Breadcrumb(message: 'test'));
      hub.configureScope((Scope scope) {
        expect(1, scope.breadcrumbs.length);
        expect('test', scope.breadcrumbs.first.message);
      });
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
      await hub.captureEvent(SentryEvent(), withScope: (scope) {
        scope.user = SentryUser(id: 'foo bar');
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
      await hub.captureException(Exception('1'), withScope: (scope) {
        scope.user = SentryUser(id: 'foo bar');
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
      await hub.captureMessage('foo bar 1', withScope: (scope) {
        scope.user = SentryUser(id: 'foo bar');
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
}

class Fixture {
  final client = MockSentryClient();
  final options = SentryOptions(dsn: fakeDsn);
  late SentryTransactionContext _context;
  late SentryTracer tracer;

  Hub getSut({
    double? tracesSampleRate = 1.0,
    TracesSamplerCallback? tracesSampler,
    bool? sampled = true,
  }) {
    options.tracesSampleRate = tracesSampleRate;
    options.tracesSampler = tracesSampler;
    final hub = Hub(options);

    _context = SentryTransactionContext(
      'name',
      'op',
      sampled: sampled,
    );

    tracer = SentryTracer(_context, hub);

    hub.bindClient(client);
    return hub;
  }
}
