import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';

void main() {
  group('StaticTransactionWrapper', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    group('transactionStackSize', () {
      test('returns 0 when no transactions are active', () {
        final sut = fixture.getSut();

        expect(sut.transactionStackSize, 0);
      });

      test('returns correct count after beginTransaction', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        expect(sut.transactionStackSize, 1);
      });
    });

    group('currentSpan', () {
      test('returns null when no transactions are active', () {
        final sut = fixture.getSut();

        expect(sut.currentSpan, isNull);
      });

      test('returns current span after beginTransaction', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        expect(sut.currentSpan, isNotNull);
        expect(sut.currentSpan, isA<ISentrySpan>());
      });
    });

    group('beginTransaction', () {
      test('creates child span and returns result with spanCreated true', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        final (result, spanCreated) = sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        expect(result, 'result');
        expect(spanCreated, true);
        final children = fixture.tracer.children;
        expect(children.length, 1);
        expect(children.first.context.operation, 'db.sql.transaction');
        expect(children.first.context.description, 'BEGIN');
        expect(children.first.status, SpanStatus.unknown());
        expect(children.first.finished, false);
      });

      test('sets origin when provided', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
          origin: 'auto.db.test',
        );

        final children = fixture.tracer.children;
        expect(children.first.origin, 'auto.db.test');
      });

      test('sets attributes when provided', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
          attributes: {'db.system': 'sqlite', 'db.name': 'test.db'},
        );

        final children = fixture.tracer.children;
        expect(children.first.data['db.system'], 'sqlite');
        expect(children.first.data['db.name'], 'test.db');
      });

      test('pushes span to stack on success', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        expect(sut.transactionStackSize, 1);
        expect(sut.currentSpan, isNotNull);
      });

      test('finishes span with error and does not push to stack on exception',
          () {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        final exception = Exception('test error');

        expect(
          () => sut.beginTransaction(
            operation: 'db.sql.transaction',
            description: 'BEGIN',
            execute: () => throw exception,
          ),
          throwsA(exception),
        );

        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.internalError());
        expect(children.first.throwable, exception);
        expect(children.first.finished, true);
        expect(sut.transactionStackSize, 0);
      });

      test('executes directly and returns spanCreated false when no parent',
          () {
        final sut = fixture.getSut();
        var executed = false;

        final (result, spanCreated) = sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () {
            executed = true;
            return 'result';
          },
        );

        expect(result, 'result');
        expect(spanCreated, false);
        expect(executed, true);
        expect(sut.transactionStackSize, 0);
      });

      test('uses currentSpan as parent for nested transactions', () {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        // First transaction
        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN outer',
          execute: () => 'outer',
        );

        final outerSpan = sut.currentSpan;

        // Nested transaction should use current span as parent
        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN inner',
          execute: () => 'inner',
        );

        final innerSpan = sut.currentSpan as SentrySpan;

        expect(sut.transactionStackSize, 2);
        // The inner span should have the outer span as parent
        expect(innerSpan.context.parentSpanId,
            (outerSpan as SentrySpan).context.spanId);
      });
    });

    group('commitTransaction', () {
      test('finishes span with ok status and pops from stack', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        final result = await sut.commitTransaction(() async {});

        expect(result, true);
        expect(sut.transactionStackSize, 0);
        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.ok());
        expect(children.first.finished, true);
      });

      test('executes the commit function', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        var commitExecuted = false;

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        await sut.commitTransaction(() async {
          commitExecuted = true;
        });

        expect(commitExecuted, true);
      });

      test('returns false when no transaction is active', () async {
        final sut = fixture.getSut();

        final result = await sut.commitTransaction(() async {});

        expect(result, false);
      });

      test('sets error status and rethrows on exception', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        final exception = Exception('commit error');

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        await expectLater(
          () => sut.commitTransaction(() async => throw exception),
          throwsA(exception),
        );

        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.internalError());
        expect(children.first.throwable, exception);
        expect(children.first.finished, true);
        expect(sut.transactionStackSize, 0);
      });

      test('commits correct transaction in nested scenario', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        // Begin outer transaction
        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN outer',
          execute: () => 'outer',
        );

        // Begin inner transaction
        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN inner',
          execute: () => 'inner',
        );

        expect(sut.transactionStackSize, 2);

        // Commit inner first
        await sut.commitTransaction(() async {});
        expect(sut.transactionStackSize, 1);

        // Commit outer
        await sut.commitTransaction(() async {});
        expect(sut.transactionStackSize, 0);
      });
    });

    group('rollbackTransaction', () {
      test('finishes span with aborted status and pops from stack', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        final result = await sut.rollbackTransaction(() async {});

        expect(result, true);
        expect(sut.transactionStackSize, 0);
        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.aborted());
        expect(children.first.finished, true);
      });

      test('executes the rollback function', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        var rollbackExecuted = false;

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        await sut.rollbackTransaction(() async {
          rollbackExecuted = true;
        });

        expect(rollbackExecuted, true);
      });

      test('returns false when no transaction is active', () async {
        final sut = fixture.getSut();

        final result = await sut.rollbackTransaction(() async {});

        expect(result, false);
      });

      test('sets error status and rethrows on exception', () async {
        final sut = fixture.getSut();
        fixture.setParentSpan();
        final exception = Exception('rollback error');

        sut.beginTransaction(
          operation: 'db.sql.transaction',
          description: 'BEGIN',
          execute: () => 'result',
        );

        await expectLater(
          () => sut.rollbackTransaction(() async => throw exception),
          throwsA(exception),
        );

        final children = fixture.tracer.children;
        expect(children.first.status, SpanStatus.internalError());
        expect(children.first.throwable, exception);
        expect(children.first.finished, true);
        expect(sut.transactionStackSize, 0);
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

  StaticTransactionWrapper getSut() {
    return StaticTransactionWrapper(hub: hub);
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
