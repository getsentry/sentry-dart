import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../../mocks/mock_hub.dart';

void main() {
  group('StaticSpanWrapper', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('wrapAsync', () {
      test('creates child span and finishes with ok status on success',
          () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        final result = await sut.wrapAsync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () async => 'result',
          loggerName: 'test',
        );

        expect(result, 'result');
        final children = fixture.tracer.children;
        expect(children.length, 1);
        expect(children.first.context.operation, 'db.query');
        expect(children.first.context.description, 'SELECT * FROM users');
        expect(children.first.status, SpanStatus.ok());
        expect(children.first.finished, true);
      });

      test('sets origin when provided', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        await sut.wrapAsync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () async => 'result',
          loggerName: 'test',
          origin: 'auto.db.test',
        );

        final children = fixture.tracer.children;
        expect(children.first.origin, 'auto.db.test');
      });

      test('sets attributes when provided', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        await sut.wrapAsync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () async => 'result',
          loggerName: 'test',
          attributes: {'db.system': 'sqlite', 'db.name': 'test.db'},
        );

        final children = fixture.tracer.children;
        expect(children.first.data['db.system'], 'sqlite');
        expect(children.first.data['db.name'], 'test.db');
      });

      test('sets throwable and internalError status on exception', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        final exception = Exception('test error');

        await expectLater(
          () => sut.wrapAsync(
            operation: 'db.query',
            description: 'SELECT * FROM users',
            execute: () async => throw exception,
            loggerName: 'test',
          ),
          throwsA(exception),
        );

        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.internalError());
        expect(children.first.throwable, exception);
        expect(children.first.finished, true);
      });

      test('executes directly when no parent span is available', () async {
        final sut = fixture.getSut();
        var executed = false;

        final result = await sut.wrapAsync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () async {
            executed = true;
            return 'result';
          },
          loggerName: 'test',
        );

        expect(result, 'result');
        expect(executed, true);
        // No spans created since no parent span available
        expect(fixture.hub.getSpanCalls, 1);
      });

      test('uses hub active span', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        await sut.wrapAsync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () async => 'result',
          loggerName: 'test',
        );

        expect(fixture.hub.getSpanCalls, 1);
        expect(fixture.tracer.children.length, 1);
      });
    });

    group('wrapSync', () {
      test('creates child span and finishes with ok status on success', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        final result = sut.wrapSync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () => 'result',
          loggerName: 'test',
        );

        expect(result, 'result');
        final children = fixture.tracer.children;
        expect(children.length, 1);
        expect(children.first.context.operation, 'db.query');
        expect(children.first.context.description, 'SELECT * FROM users');
        expect(children.first.status, SpanStatus.ok());
        expect(children.first.finished, true);
      });

      test('sets origin when provided', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.wrapSync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () => 'result',
          loggerName: 'test',
          origin: 'auto.db.test',
        );

        final children = fixture.tracer.children;
        expect(children.first.origin, 'auto.db.test');
      });

      test('sets attributes when provided', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.wrapSync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () => 'result',
          loggerName: 'test',
          attributes: {'db.system': 'sqlite', 'db.name': 'test.db'},
        );

        final children = fixture.tracer.children;
        expect(children.first.data['db.system'], 'sqlite');
        expect(children.first.data['db.name'], 'test.db');
      });

      test('sets throwable and internalError status on exception', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        final exception = Exception('test error');

        expect(
          () => sut.wrapSync(
            operation: 'db.query',
            description: 'SELECT * FROM users',
            execute: () => throw exception,
            loggerName: 'test',
          ),
          throwsA(exception),
        );

        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.internalError());
        expect(children.first.throwable, exception);
        expect(children.first.finished, true);
      });

      test('executes directly when no parent span is available', () {
        final sut = fixture.getSut();
        var executed = false;

        final result = sut.wrapSync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () {
            executed = true;
            return 'result';
          },
          loggerName: 'test',
        );

        expect(result, 'result');
        expect(executed, true);
        // No spans created since no parent span available
        expect(fixture.hub.getSpanCalls, 1);
      });

      test('uses hub active span', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.wrapSync(
          operation: 'db.query',
          description: 'SELECT * FROM users',
          execute: () => 'result',
          loggerName: 'test',
        );

        expect(fixture.hub.getSpanCalls, 1);
        expect(fixture.tracer.children.length, 1);
      });
    });
  });
}

class Fixture {
  late SentryTracer tracer;
  late MockHubWithSpan hub;

  Fixture() {
    hub = MockHubWithSpan();
  }

  StaticSpanWrapper getSut() {
    return StaticSpanWrapper(hub: hub);
  }

  void setParentSpan() {
    final context = SentryTransactionContext('name', 'op', origin: 'manual');
    tracer = SentryTracer(context, hub);
    hub.getSpanReturnValue = tracer;
  }
}

class MockHubWithSpan extends MockHub {
  ISentrySpan? getSpanReturnValue;

  @override
  ISentrySpan? getSpan() {
    getSpanCalls++;
    return getSpanReturnValue;
  }
}
