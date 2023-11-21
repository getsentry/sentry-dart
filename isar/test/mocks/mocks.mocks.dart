// Mocks generated by Mockito 5.4.2 from annotations
// in sentry_isar/test/mocks/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:isar/isar.dart' as _i4;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i6;
import 'package:sentry/sentry.dart' as _i2;
import 'package:sentry/src/profiling.dart' as _i5;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeSentryOptions_0 extends _i1.SmartFake implements _i2.SentryOptions {
  _FakeSentryOptions_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryId_1 extends _i1.SmartFake implements _i2.SentryId {
  _FakeSentryId_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeScope_2 extends _i1.SmartFake implements _i2.Scope {
  _FakeScope_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeHub_3 extends _i1.SmartFake implements _i2.Hub {
  _FakeHub_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeISentrySpan_4 extends _i1.SmartFake implements _i2.ISentrySpan {
  _FakeISentrySpan_4(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeFuture_5<T1> extends _i1.SmartFake implements _i3.Future<T1> {
  _FakeFuture_5(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeIsarCollection_6<OBJ> extends _i1.SmartFake
    implements _i4.IsarCollection<OBJ> {
  _FakeIsarCollection_6(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
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
  bool get isEnabled => (super.noSuchMethod(
        Invocation.getter(#isEnabled),
        returnValue: false,
      ) as bool);

  @override
  _i2.SentryId get lastEventId => (super.noSuchMethod(
        Invocation.getter(#lastEventId),
        returnValue: _FakeSentryId_1(
          this,
          Invocation.getter(#lastEventId),
        ),
      ) as _i2.SentryId);

  @override
  _i2.Scope get scope => (super.noSuchMethod(
        Invocation.getter(#scope),
        returnValue: _FakeScope_2(
          this,
          Invocation.getter(#scope),
        ),
      ) as _i2.Scope);

  @override
  set profilerFactory(_i5.SentryProfilerFactory? value) => super.noSuchMethod(
        Invocation.setter(
          #profilerFactory,
          value,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Future<_i2.SentryId> captureEvent(
    _i2.SentryEvent? event, {
    dynamic stackTrace,
    _i2.Hint? hint,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureEvent,
          [event],
          {
            #stackTrace: stackTrace,
            #hint: hint,
            #withScope: withScope,
          },
        ),
        returnValue: _i3.Future<_i2.SentryId>.value(_FakeSentryId_1(
          this,
          Invocation.method(
            #captureEvent,
            [event],
            {
              #stackTrace: stackTrace,
              #hint: hint,
              #withScope: withScope,
            },
          ),
        )),
      ) as _i3.Future<_i2.SentryId>);

  @override
  _i3.Future<_i2.SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    _i2.Hint? hint,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureException,
          [throwable],
          {
            #stackTrace: stackTrace,
            #hint: hint,
            #withScope: withScope,
          },
        ),
        returnValue: _i3.Future<_i2.SentryId>.value(_FakeSentryId_1(
          this,
          Invocation.method(
            #captureException,
            [throwable],
            {
              #stackTrace: stackTrace,
              #hint: hint,
              #withScope: withScope,
            },
          ),
        )),
      ) as _i3.Future<_i2.SentryId>);

  @override
  _i3.Future<_i2.SentryId> captureMessage(
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
        returnValue: _i3.Future<_i2.SentryId>.value(_FakeSentryId_1(
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
        )),
      ) as _i3.Future<_i2.SentryId>);

  @override
  _i3.Future<void> captureUserFeedback(_i2.SentryUserFeedback? userFeedback) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureUserFeedback,
          [userFeedback],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  _i3.Future<void> addBreadcrumb(
    _i2.Breadcrumb? crumb, {
    _i2.Hint? hint,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #addBreadcrumb,
          [crumb],
          {#hint: hint},
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  void bindClient(_i2.SentryClient? client) => super.noSuchMethod(
        Invocation.method(
          #bindClient,
          [client],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i2.Hub clone() => (super.noSuchMethod(
        Invocation.method(
          #clone,
          [],
        ),
        returnValue: _FakeHub_3(
          this,
          Invocation.method(
            #clone,
            [],
          ),
        ),
      ) as _i2.Hub);

  @override
  _i3.Future<void> close() => (super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  _i3.FutureOr<void> configureScope(_i2.ScopeCallback? callback) =>
      (super.noSuchMethod(Invocation.method(
        #configureScope,
        [callback],
      )) as _i3.FutureOr<void>);

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
          [
            name,
            operation,
          ],
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
            [
              name,
              operation,
            ],
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
  _i3.Future<_i2.SentryId> captureTransaction(
    _i2.SentryTransaction? transaction, {
    _i2.SentryTraceContextHeader? traceContext,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureTransaction,
          [transaction],
          {#traceContext: traceContext},
        ),
        returnValue: _i3.Future<_i2.SentryId>.value(_FakeSentryId_1(
          this,
          Invocation.method(
            #captureTransaction,
            [transaction],
            {#traceContext: traceContext},
          ),
        )),
      ) as _i3.Future<_i2.SentryId>);

  @override
  void setSpanContext(
    dynamic throwable,
    _i2.ISentrySpan? span,
    String? transaction,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setSpanContext,
          [
            throwable,
            span,
            transaction,
          ],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [Isar].
///
/// See the documentation for Mockito's code generation for more information.
class MockIsar extends _i1.Mock implements _i4.Isar {
  MockIsar() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name => (super.noSuchMethod(
        Invocation.getter(#name),
        returnValue: '',
      ) as String);

  @override
  bool get isOpen => (super.noSuchMethod(
        Invocation.getter(#isOpen),
        returnValue: false,
      ) as bool);

  @override
  void requireOpen() => super.noSuchMethod(
        Invocation.method(
          #requireOpen,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Future<T> txn<T>(_i3.Future<T> Function()? callback) =>
      (super.noSuchMethod(
        Invocation.method(
          #txn,
          [callback],
        ),
        returnValue: _i6.ifNotNull(
              _i6.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #txn,
                  [callback],
                ),
              ),
              (T v) => _i3.Future<T>.value(v),
            ) ??
            _FakeFuture_5<T>(
              this,
              Invocation.method(
                #txn,
                [callback],
              ),
            ),
      ) as _i3.Future<T>);

  @override
  _i3.Future<T> writeTxn<T>(
    _i3.Future<T> Function()? callback, {
    bool? silent = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #writeTxn,
          [callback],
          {#silent: silent},
        ),
        returnValue: _i6.ifNotNull(
              _i6.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #writeTxn,
                  [callback],
                  {#silent: silent},
                ),
              ),
              (T v) => _i3.Future<T>.value(v),
            ) ??
            _FakeFuture_5<T>(
              this,
              Invocation.method(
                #writeTxn,
                [callback],
                {#silent: silent},
              ),
            ),
      ) as _i3.Future<T>);

  @override
  T txnSync<T>(T Function()? callback) => (super.noSuchMethod(
        Invocation.method(
          #txnSync,
          [callback],
        ),
        returnValue: _i6.dummyValue<T>(
          this,
          Invocation.method(
            #txnSync,
            [callback],
          ),
        ),
      ) as T);

  @override
  T writeTxnSync<T>(
    T Function()? callback, {
    bool? silent = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #writeTxnSync,
          [callback],
          {#silent: silent},
        ),
        returnValue: _i6.dummyValue<T>(
          this,
          Invocation.method(
            #writeTxnSync,
            [callback],
            {#silent: silent},
          ),
        ),
      ) as T);

  @override
  void attachCollections(Map<Type, _i4.IsarCollection<dynamic>>? collections) =>
      super.noSuchMethod(
        Invocation.method(
          #attachCollections,
          [collections],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i4.IsarCollection<T> collection<T>() => (super.noSuchMethod(
        Invocation.method(
          #collection,
          [],
        ),
        returnValue: _FakeIsarCollection_6<T>(
          this,
          Invocation.method(
            #collection,
            [],
          ),
        ),
      ) as _i4.IsarCollection<T>);

  @override
  _i4.IsarCollection<dynamic>? getCollectionByNameInternal(String? name) =>
      (super.noSuchMethod(Invocation.method(
        #getCollectionByNameInternal,
        [name],
      )) as _i4.IsarCollection<dynamic>?);

  @override
  _i3.Future<void> clear() => (super.noSuchMethod(
        Invocation.method(
          #clear,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  void clearSync() => super.noSuchMethod(
        Invocation.method(
          #clearSync,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Future<int> getSize({
    bool? includeIndexes = false,
    bool? includeLinks = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getSize,
          [],
          {
            #includeIndexes: includeIndexes,
            #includeLinks: includeLinks,
          },
        ),
        returnValue: _i3.Future<int>.value(0),
      ) as _i3.Future<int>);

  @override
  int getSizeSync({
    bool? includeIndexes = false,
    bool? includeLinks = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #getSizeSync,
          [],
          {
            #includeIndexes: includeIndexes,
            #includeLinks: includeLinks,
          },
        ),
        returnValue: 0,
      ) as int);

  @override
  _i3.Future<void> copyToFile(String? targetPath) => (super.noSuchMethod(
        Invocation.method(
          #copyToFile,
          [targetPath],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  _i3.Future<bool> close({bool? deleteFromDisk = false}) => (super.noSuchMethod(
        Invocation.method(
          #close,
          [],
          {#deleteFromDisk: deleteFromDisk},
        ),
        returnValue: _i3.Future<bool>.value(false),
      ) as _i3.Future<bool>);

  @override
  _i3.Future<void> verify() => (super.noSuchMethod(
        Invocation.method(
          #verify,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);
}
