// Mocks generated by Mockito 5.4.5 from annotations
// in sentry_drift/test/mocks/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;

import 'package:drift/backends.dart' as _i3;
import 'package:drift/drift.dart' as _i6;
import 'package:mockito/mockito.dart' as _i1;
import 'package:sentry/sentry.dart' as _i2;
import 'package:sentry/src/profiling.dart' as _i4;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeSentryOptions_0 extends _i1.SmartFake implements _i2.SentryOptions {
  _FakeSentryOptions_0(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeSentryId_1 extends _i1.SmartFake implements _i2.SentryId {
  _FakeSentryId_1(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeScope_2 extends _i1.SmartFake implements _i2.Scope {
  _FakeScope_2(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeHub_3 extends _i1.SmartFake implements _i2.Hub {
  _FakeHub_3(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeISentrySpan_4 extends _i1.SmartFake implements _i2.ISentrySpan {
  _FakeISentrySpan_4(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeQueryExecutor_5 extends _i1.SmartFake implements _i3.QueryExecutor {
  _FakeQueryExecutor_5(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeTransactionExecutor_6 extends _i1.SmartFake
    implements _i3.TransactionExecutor {
  _FakeTransactionExecutor_6(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

/// A class which mocks [Hub].
///
/// See the documentation for Mockito's code generation for more information.
class MockHub extends _i1.Mock implements _i2.Hub {
  MockHub() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.SentryOptions get options => (super.noSuchMethod(
        Invocation.getter(#options),
        returnValue: _FakeSentryOptions_0(
          this,
          Invocation.getter(#options),
        ),
      ) as _i2.SentryOptions);

  @override
  bool get isEnabled =>
      (super.noSuchMethod(Invocation.getter(#isEnabled), returnValue: false)
          as bool);

  @override
  _i2.SentryId get lastEventId => (super.noSuchMethod(
        Invocation.getter(#lastEventId),
        returnValue: _FakeSentryId_1(this, Invocation.getter(#lastEventId)),
      ) as _i2.SentryId);

  @override
  _i2.Scope get scope => (super.noSuchMethod(
        Invocation.getter(#scope),
        returnValue: _FakeScope_2(this, Invocation.getter(#scope)),
      ) as _i2.Scope);

  @override
  set profilerFactory(_i4.SentryProfilerFactory? value) => super.noSuchMethod(
        Invocation.setter(#profilerFactory, value),
        returnValueForMissingStub: null,
      );

  @override
  _i5.Future<_i2.SentryId> captureEvent(
    _i2.SentryEvent? event, {
    dynamic stackTrace,
    _i2.Hint? hint,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureEvent,
          [event],
          {#stackTrace: stackTrace, #hint: hint, #withScope: withScope},
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(
          _FakeSentryId_1(
            this,
            Invocation.method(
              #captureEvent,
              [event],
              {#stackTrace: stackTrace, #hint: hint, #withScope: withScope},
            ),
          ),
        ),
      ) as _i5.Future<_i2.SentryId>);

  @override
  _i5.Future<_i2.SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    _i2.Hint? hint,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureException,
          [throwable],
          {#stackTrace: stackTrace, #hint: hint, #withScope: withScope},
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(
          _FakeSentryId_1(
            this,
            Invocation.method(
              #captureException,
              [throwable],
              {#stackTrace: stackTrace, #hint: hint, #withScope: withScope},
            ),
          ),
        ),
      ) as _i5.Future<_i2.SentryId>);

  @override
  _i5.Future<_i2.SentryId> captureMessage(
    String? message, {
    _i2.SentryLevel? level,
    String? template,
    List<dynamic>? params,
    _i2.Hint? hint,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureMessage,
          [message],
          {
            #level: level,
            #template: template,
            #params: params,
            #hint: hint,
            #withScope: withScope,
          },
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(
          _FakeSentryId_1(
            this,
            Invocation.method(
              #captureMessage,
              [message],
              {
                #level: level,
                #template: template,
                #params: params,
                #hint: hint,
                #withScope: withScope,
              },
            ),
          ),
        ),
      ) as _i5.Future<_i2.SentryId>);

  @override
  _i5.Future<_i2.SentryId> captureFeedback(
    _i2.SentryFeedback? feedback, {
    _i2.Hint? hint,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureFeedback,
          [feedback],
          {#hint: hint, #withScope: withScope},
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(
          _FakeSentryId_1(
            this,
            Invocation.method(
              #captureFeedback,
              [feedback],
              {#hint: hint, #withScope: withScope},
            ),
          ),
        ),
      ) as _i5.Future<_i2.SentryId>);

  @override
  _i5.Future<void> addBreadcrumb(_i2.Breadcrumb? crumb, {_i2.Hint? hint}) =>
      (super.noSuchMethod(
        Invocation.method(#addBreadcrumb, [crumb], {#hint: hint}),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  void bindClient(_i2.SentryClient? client) => super.noSuchMethod(
        Invocation.method(#bindClient, [client]),
        returnValueForMissingStub: null,
      );

  @override
  _i2.Hub clone() => (super.noSuchMethod(
        Invocation.method(#clone, []),
        returnValue: _FakeHub_3(this, Invocation.method(#clone, [])),
      ) as _i2.Hub);

  @override
  _i5.Future<void> close() => (super.noSuchMethod(
        Invocation.method(#close, []),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.FutureOr<void> configureScope(_i2.ScopeCallback? callback) =>
      (super.noSuchMethod(Invocation.method(#configureScope, [callback]))
          as _i5.FutureOr<void>);

  @override
  _i2.ISentrySpan startTransaction(
    String? name,
    String? operation, {
    String? description,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    _i2.OnTransactionFinish? onFinish,
    Map<String, dynamic>? customSamplingContext,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startTransaction,
          [name, operation],
          {
            #description: description,
            #startTimestamp: startTimestamp,
            #bindToScope: bindToScope,
            #waitForChildren: waitForChildren,
            #autoFinishAfter: autoFinishAfter,
            #trimEnd: trimEnd,
            #onFinish: onFinish,
            #customSamplingContext: customSamplingContext,
          },
        ),
        returnValue: _FakeISentrySpan_4(
          this,
          Invocation.method(
            #startTransaction,
            [name, operation],
            {
              #description: description,
              #startTimestamp: startTimestamp,
              #bindToScope: bindToScope,
              #waitForChildren: waitForChildren,
              #autoFinishAfter: autoFinishAfter,
              #trimEnd: trimEnd,
              #onFinish: onFinish,
              #customSamplingContext: customSamplingContext,
            },
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  _i2.ISentrySpan startTransactionWithContext(
    _i2.SentryTransactionContext? transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
    _i2.OnTransactionFinish? onFinish,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startTransactionWithContext,
          [transactionContext],
          {
            #customSamplingContext: customSamplingContext,
            #startTimestamp: startTimestamp,
            #bindToScope: bindToScope,
            #waitForChildren: waitForChildren,
            #autoFinishAfter: autoFinishAfter,
            #trimEnd: trimEnd,
            #onFinish: onFinish,
          },
        ),
        returnValue: _FakeISentrySpan_4(
          this,
          Invocation.method(
            #startTransactionWithContext,
            [transactionContext],
            {
              #customSamplingContext: customSamplingContext,
              #startTimestamp: startTimestamp,
              #bindToScope: bindToScope,
              #waitForChildren: waitForChildren,
              #autoFinishAfter: autoFinishAfter,
              #trimEnd: trimEnd,
              #onFinish: onFinish,
            },
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  _i5.Future<_i2.SentryId> captureTransaction(
    _i2.SentryTransaction? transaction, {
    _i2.SentryTraceContextHeader? traceContext,
    _i2.Hint? hint,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureTransaction,
          [transaction],
          {#traceContext: traceContext, #hint: hint},
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(
          _FakeSentryId_1(
            this,
            Invocation.method(
              #captureTransaction,
              [transaction],
              {#traceContext: traceContext, #hint: hint},
            ),
          ),
        ),
      ) as _i5.Future<_i2.SentryId>);

  @override
  void setSpanContext(
    dynamic throwable,
    _i2.ISentrySpan? span,
    String? transaction,
  ) =>
      super.noSuchMethod(
        Invocation.method(#setSpanContext, [throwable, span, transaction]),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [LazyDatabase].
///
/// See the documentation for Mockito's code generation for more information.
class MockLazyDatabase extends _i1.Mock implements _i6.LazyDatabase {
  MockLazyDatabase() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i6.DatabaseOpener get opener => (super.noSuchMethod(
        Invocation.getter(#opener),
        returnValue: () => _i5.Future<_i3.QueryExecutor>.value(
          _FakeQueryExecutor_5(this, Invocation.getter(#opener)),
        ),
      ) as _i6.DatabaseOpener);

  @override
  _i3.SqlDialect get dialect => (super.noSuchMethod(
        Invocation.getter(#dialect),
        returnValue: _i3.SqlDialect.sqlite,
      ) as _i3.SqlDialect);

  @override
  _i3.QueryExecutor beginExclusive() => (super.noSuchMethod(
        Invocation.method(#beginExclusive, []),
        returnValue: _FakeQueryExecutor_5(
          this,
          Invocation.method(#beginExclusive, []),
        ),
      ) as _i3.QueryExecutor);

  @override
  _i3.TransactionExecutor beginTransaction() => (super.noSuchMethod(
        Invocation.method(#beginTransaction, []),
        returnValue: _FakeTransactionExecutor_6(
          this,
          Invocation.method(#beginTransaction, []),
        ),
      ) as _i3.TransactionExecutor);

  @override
  _i5.Future<bool> ensureOpen(_i3.QueryExecutorUser? user) =>
      (super.noSuchMethod(
        Invocation.method(#ensureOpen, [user]),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<void> runBatched(_i3.BatchedStatements? statements) =>
      (super.noSuchMethod(
        Invocation.method(#runBatched, [statements]),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<void> runCustom(String? statement, [List<Object?>? args]) =>
      (super.noSuchMethod(
        Invocation.method(#runCustom, [statement, args]),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<int> runDelete(String? statement, List<Object?>? args) =>
      (super.noSuchMethod(
        Invocation.method(#runDelete, [statement, args]),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<int> runInsert(String? statement, List<Object?>? args) =>
      (super.noSuchMethod(
        Invocation.method(#runInsert, [statement, args]),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<List<Map<String, Object?>>> runSelect(
    String? statement,
    List<Object?>? args,
  ) =>
      (super.noSuchMethod(
        Invocation.method(#runSelect, [statement, args]),
        returnValue: _i5.Future<List<Map<String, Object?>>>.value(
          <Map<String, Object?>>[],
        ),
      ) as _i5.Future<List<Map<String, Object?>>>);

  @override
  _i5.Future<int> runUpdate(String? statement, List<Object?>? args) =>
      (super.noSuchMethod(
        Invocation.method(#runUpdate, [statement, args]),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<void> close() => (super.noSuchMethod(
        Invocation.method(#close, []),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);
}

/// A class which mocks [QueryExecutor].
///
/// See the documentation for Mockito's code generation for more information.
class MockQueryExecutor extends _i1.Mock implements _i3.QueryExecutor {
  MockQueryExecutor() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.SqlDialect get dialect => (super.noSuchMethod(
        Invocation.getter(#dialect),
        returnValue: _i3.SqlDialect.sqlite,
      ) as _i3.SqlDialect);

  @override
  _i5.Future<bool> ensureOpen(_i3.QueryExecutorUser? user) =>
      (super.noSuchMethod(
        Invocation.method(#ensureOpen, [user]),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<List<Map<String, Object?>>> runSelect(
    String? statement,
    List<Object?>? args,
  ) =>
      (super.noSuchMethod(
        Invocation.method(#runSelect, [statement, args]),
        returnValue: _i5.Future<List<Map<String, Object?>>>.value(
          <Map<String, Object?>>[],
        ),
      ) as _i5.Future<List<Map<String, Object?>>>);

  @override
  _i5.Future<int> runInsert(String? statement, List<Object?>? args) =>
      (super.noSuchMethod(
        Invocation.method(#runInsert, [statement, args]),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<int> runUpdate(String? statement, List<Object?>? args) =>
      (super.noSuchMethod(
        Invocation.method(#runUpdate, [statement, args]),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<int> runDelete(String? statement, List<Object?>? args) =>
      (super.noSuchMethod(
        Invocation.method(#runDelete, [statement, args]),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<void> runCustom(String? statement, [List<Object?>? args]) =>
      (super.noSuchMethod(
        Invocation.method(#runCustom, [statement, args]),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<void> runBatched(_i3.BatchedStatements? statements) =>
      (super.noSuchMethod(
        Invocation.method(#runBatched, [statements]),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i3.TransactionExecutor beginTransaction() => (super.noSuchMethod(
        Invocation.method(#beginTransaction, []),
        returnValue: _FakeTransactionExecutor_6(
          this,
          Invocation.method(#beginTransaction, []),
        ),
      ) as _i3.TransactionExecutor);

  @override
  _i3.QueryExecutor beginExclusive() => (super.noSuchMethod(
        Invocation.method(#beginExclusive, []),
        returnValue: _FakeQueryExecutor_5(
          this,
          Invocation.method(#beginExclusive, []),
        ),
      ) as _i3.QueryExecutor);

  @override
  _i5.Future<void> close() => (super.noSuchMethod(
        Invocation.method(#close, []),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);
}
