// Mocks generated by Mockito 5.4.5 from annotations
// in sentry_hive/test/mocks/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i9;

import 'package:hive/hive.dart' as _i3;
import 'package:hive/src/box/default_compaction_strategy.dart' as _i8;
import 'package:hive/src/box/default_key_comparator.dart' as _i7;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i6;
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

class _FakeBox_5<E1> extends _i1.SmartFake implements _i3.Box<E1> {
  _FakeBox_5(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeLazyBox_6<E1> extends _i1.SmartFake implements _i3.LazyBox<E1> {
  _FakeLazyBox_6(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeCollectionBox_7<V1> extends _i1.SmartFake
    implements _i3.CollectionBox<V1> {
  _FakeCollectionBox_7(Object parent, Invocation parentInvocation)
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
  _i2.SentryOptions get options =>
      (super.noSuchMethod(
            Invocation.getter(#options),
            returnValue: _FakeSentryOptions_0(
              this,
              Invocation.getter(#options),
            ),
          )
          as _i2.SentryOptions);

  @override
  bool get isEnabled =>
      (super.noSuchMethod(Invocation.getter(#isEnabled), returnValue: false)
          as bool);

  @override
  _i2.SentryId get lastEventId =>
      (super.noSuchMethod(
            Invocation.getter(#lastEventId),
            returnValue: _FakeSentryId_1(this, Invocation.getter(#lastEventId)),
          )
          as _i2.SentryId);

  @override
  _i2.Scope get scope =>
      (super.noSuchMethod(
            Invocation.getter(#scope),
            returnValue: _FakeScope_2(this, Invocation.getter(#scope)),
          )
          as _i2.Scope);

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
          )
          as _i5.Future<_i2.SentryId>);

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
          )
          as _i5.Future<_i2.SentryId>);

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
          )
          as _i5.Future<_i2.SentryId>);

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
          )
          as _i5.Future<_i2.SentryId>);

  @override
  _i5.Future<void> addBreadcrumb(_i2.Breadcrumb? crumb, {_i2.Hint? hint}) =>
      (super.noSuchMethod(
            Invocation.method(#addBreadcrumb, [crumb], {#hint: hint}),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  void bindClient(_i2.SentryClient? client) => super.noSuchMethod(
    Invocation.method(#bindClient, [client]),
    returnValueForMissingStub: null,
  );

  @override
  _i2.Hub clone() =>
      (super.noSuchMethod(
            Invocation.method(#clone, []),
            returnValue: _FakeHub_3(this, Invocation.method(#clone, [])),
          )
          as _i2.Hub);

  @override
  _i5.Future<void> close() =>
      (super.noSuchMethod(
            Invocation.method(#close, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

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
          )
          as _i2.ISentrySpan);

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
          )
          as _i2.ISentrySpan);

  @override
  _i5.Future<_i2.SentryId> captureTransaction(
    _i2.SentryTransaction? transaction, {
    _i2.SentryTraceContextHeader? traceContext,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #captureTransaction,
              [transaction],
              {#traceContext: traceContext},
            ),
            returnValue: _i5.Future<_i2.SentryId>.value(
              _FakeSentryId_1(
                this,
                Invocation.method(
                  #captureTransaction,
                  [transaction],
                  {#traceContext: traceContext},
                ),
              ),
            ),
          )
          as _i5.Future<_i2.SentryId>);

  @override
  void setSpanContext(
    dynamic throwable,
    _i2.ISentrySpan? span,
    String? transaction,
  ) => super.noSuchMethod(
    Invocation.method(#setSpanContext, [throwable, span, transaction]),
    returnValueForMissingStub: null,
  );
}

/// A class which mocks [Box].
///
/// See the documentation for Mockito's code generation for more information.
class MockBox<E> extends _i1.Mock implements _i3.Box<E> {
  MockBox() {
    _i1.throwOnMissingStub(this);
  }

  @override
  Iterable<E> get values =>
      (super.noSuchMethod(Invocation.getter(#values), returnValue: <E>[])
          as Iterable<E>);

  @override
  String get name =>
      (super.noSuchMethod(
            Invocation.getter(#name),
            returnValue: _i6.dummyValue<String>(this, Invocation.getter(#name)),
          )
          as String);

  @override
  bool get isOpen =>
      (super.noSuchMethod(Invocation.getter(#isOpen), returnValue: false)
          as bool);

  @override
  bool get lazy =>
      (super.noSuchMethod(Invocation.getter(#lazy), returnValue: false)
          as bool);

  @override
  Iterable<dynamic> get keys =>
      (super.noSuchMethod(Invocation.getter(#keys), returnValue: <dynamic>[])
          as Iterable<dynamic>);

  @override
  int get length =>
      (super.noSuchMethod(Invocation.getter(#length), returnValue: 0) as int);

  @override
  bool get isEmpty =>
      (super.noSuchMethod(Invocation.getter(#isEmpty), returnValue: false)
          as bool);

  @override
  bool get isNotEmpty =>
      (super.noSuchMethod(Invocation.getter(#isNotEmpty), returnValue: false)
          as bool);

  @override
  Iterable<E> valuesBetween({dynamic startKey, dynamic endKey}) =>
      (super.noSuchMethod(
            Invocation.method(#valuesBetween, [], {
              #startKey: startKey,
              #endKey: endKey,
            }),
            returnValue: <E>[],
          )
          as Iterable<E>);

  @override
  E? getAt(int? index) =>
      (super.noSuchMethod(Invocation.method(#getAt, [index])) as E?);

  @override
  Map<dynamic, E> toMap() =>
      (super.noSuchMethod(
            Invocation.method(#toMap, []),
            returnValue: <dynamic, E>{},
          )
          as Map<dynamic, E>);

  @override
  dynamic keyAt(int? index) =>
      super.noSuchMethod(Invocation.method(#keyAt, [index]));

  @override
  _i5.Stream<_i3.BoxEvent> watch({dynamic key}) =>
      (super.noSuchMethod(
            Invocation.method(#watch, [], {#key: key}),
            returnValue: _i5.Stream<_i3.BoxEvent>.empty(),
          )
          as _i5.Stream<_i3.BoxEvent>);

  @override
  bool containsKey(dynamic key) =>
      (super.noSuchMethod(
            Invocation.method(#containsKey, [key]),
            returnValue: false,
          )
          as bool);

  @override
  _i5.Future<void> put(dynamic key, E? value) =>
      (super.noSuchMethod(
            Invocation.method(#put, [key, value]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> putAt(int? index, E? value) =>
      (super.noSuchMethod(
            Invocation.method(#putAt, [index, value]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> putAll(Map<dynamic, E>? entries) =>
      (super.noSuchMethod(
            Invocation.method(#putAll, [entries]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<int> add(E? value) =>
      (super.noSuchMethod(
            Invocation.method(#add, [value]),
            returnValue: _i5.Future<int>.value(0),
          )
          as _i5.Future<int>);

  @override
  _i5.Future<Iterable<int>> addAll(Iterable<E>? values) =>
      (super.noSuchMethod(
            Invocation.method(#addAll, [values]),
            returnValue: _i5.Future<Iterable<int>>.value(<int>[]),
          )
          as _i5.Future<Iterable<int>>);

  @override
  _i5.Future<void> delete(dynamic key) =>
      (super.noSuchMethod(
            Invocation.method(#delete, [key]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteAt(int? index) =>
      (super.noSuchMethod(
            Invocation.method(#deleteAt, [index]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteAll(Iterable<dynamic>? keys) =>
      (super.noSuchMethod(
            Invocation.method(#deleteAll, [keys]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> compact() =>
      (super.noSuchMethod(
            Invocation.method(#compact, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<int> clear() =>
      (super.noSuchMethod(
            Invocation.method(#clear, []),
            returnValue: _i5.Future<int>.value(0),
          )
          as _i5.Future<int>);

  @override
  _i5.Future<void> close() =>
      (super.noSuchMethod(
            Invocation.method(#close, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteFromDisk() =>
      (super.noSuchMethod(
            Invocation.method(#deleteFromDisk, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> flush() =>
      (super.noSuchMethod(
            Invocation.method(#flush, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);
}

/// A class which mocks [LazyBox].
///
/// See the documentation for Mockito's code generation for more information.
class MockLazyBox<E> extends _i1.Mock implements _i3.LazyBox<E> {
  MockLazyBox() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name =>
      (super.noSuchMethod(
            Invocation.getter(#name),
            returnValue: _i6.dummyValue<String>(this, Invocation.getter(#name)),
          )
          as String);

  @override
  bool get isOpen =>
      (super.noSuchMethod(Invocation.getter(#isOpen), returnValue: false)
          as bool);

  @override
  bool get lazy =>
      (super.noSuchMethod(Invocation.getter(#lazy), returnValue: false)
          as bool);

  @override
  Iterable<dynamic> get keys =>
      (super.noSuchMethod(Invocation.getter(#keys), returnValue: <dynamic>[])
          as Iterable<dynamic>);

  @override
  int get length =>
      (super.noSuchMethod(Invocation.getter(#length), returnValue: 0) as int);

  @override
  bool get isEmpty =>
      (super.noSuchMethod(Invocation.getter(#isEmpty), returnValue: false)
          as bool);

  @override
  bool get isNotEmpty =>
      (super.noSuchMethod(Invocation.getter(#isNotEmpty), returnValue: false)
          as bool);

  @override
  _i5.Future<E?> get(dynamic key, {E? defaultValue}) =>
      (super.noSuchMethod(
            Invocation.method(#get, [key], {#defaultValue: defaultValue}),
            returnValue: _i5.Future<E?>.value(),
          )
          as _i5.Future<E?>);

  @override
  _i5.Future<E?> getAt(int? index) =>
      (super.noSuchMethod(
            Invocation.method(#getAt, [index]),
            returnValue: _i5.Future<E?>.value(),
          )
          as _i5.Future<E?>);

  @override
  dynamic keyAt(int? index) =>
      super.noSuchMethod(Invocation.method(#keyAt, [index]));

  @override
  _i5.Stream<_i3.BoxEvent> watch({dynamic key}) =>
      (super.noSuchMethod(
            Invocation.method(#watch, [], {#key: key}),
            returnValue: _i5.Stream<_i3.BoxEvent>.empty(),
          )
          as _i5.Stream<_i3.BoxEvent>);

  @override
  bool containsKey(dynamic key) =>
      (super.noSuchMethod(
            Invocation.method(#containsKey, [key]),
            returnValue: false,
          )
          as bool);

  @override
  _i5.Future<void> put(dynamic key, E? value) =>
      (super.noSuchMethod(
            Invocation.method(#put, [key, value]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> putAt(int? index, E? value) =>
      (super.noSuchMethod(
            Invocation.method(#putAt, [index, value]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> putAll(Map<dynamic, E>? entries) =>
      (super.noSuchMethod(
            Invocation.method(#putAll, [entries]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<int> add(E? value) =>
      (super.noSuchMethod(
            Invocation.method(#add, [value]),
            returnValue: _i5.Future<int>.value(0),
          )
          as _i5.Future<int>);

  @override
  _i5.Future<Iterable<int>> addAll(Iterable<E>? values) =>
      (super.noSuchMethod(
            Invocation.method(#addAll, [values]),
            returnValue: _i5.Future<Iterable<int>>.value(<int>[]),
          )
          as _i5.Future<Iterable<int>>);

  @override
  _i5.Future<void> delete(dynamic key) =>
      (super.noSuchMethod(
            Invocation.method(#delete, [key]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteAt(int? index) =>
      (super.noSuchMethod(
            Invocation.method(#deleteAt, [index]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteAll(Iterable<dynamic>? keys) =>
      (super.noSuchMethod(
            Invocation.method(#deleteAll, [keys]),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> compact() =>
      (super.noSuchMethod(
            Invocation.method(#compact, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<int> clear() =>
      (super.noSuchMethod(
            Invocation.method(#clear, []),
            returnValue: _i5.Future<int>.value(0),
          )
          as _i5.Future<int>);

  @override
  _i5.Future<void> close() =>
      (super.noSuchMethod(
            Invocation.method(#close, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteFromDisk() =>
      (super.noSuchMethod(
            Invocation.method(#deleteFromDisk, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> flush() =>
      (super.noSuchMethod(
            Invocation.method(#flush, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);
}

/// A class which mocks [HiveInterface].
///
/// See the documentation for Mockito's code generation for more information.
class MockHiveInterface extends _i1.Mock implements _i3.HiveInterface {
  MockHiveInterface() {
    _i1.throwOnMissingStub(this);
  }

  @override
  void init(
    String? path, {
    _i3.HiveStorageBackendPreference? backendPreference =
        _i3.HiveStorageBackendPreference.native,
  }) => super.noSuchMethod(
    Invocation.method(#init, [path], {#backendPreference: backendPreference}),
    returnValueForMissingStub: null,
  );

  @override
  _i5.Future<_i3.Box<E>> openBox<E>(
    String? name, {
    _i3.HiveCipher? encryptionCipher,
    _i3.KeyComparator? keyComparator = _i7.defaultKeyComparator,
    _i3.CompactionStrategy? compactionStrategy = _i8.defaultCompactionStrategy,
    bool? crashRecovery = true,
    String? path,
    _i9.Uint8List? bytes,
    String? collection,
    List<int>? encryptionKey,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #openBox,
              [name],
              {
                #encryptionCipher: encryptionCipher,
                #keyComparator: keyComparator,
                #compactionStrategy: compactionStrategy,
                #crashRecovery: crashRecovery,
                #path: path,
                #bytes: bytes,
                #collection: collection,
                #encryptionKey: encryptionKey,
              },
            ),
            returnValue: _i5.Future<_i3.Box<E>>.value(
              _FakeBox_5<E>(
                this,
                Invocation.method(
                  #openBox,
                  [name],
                  {
                    #encryptionCipher: encryptionCipher,
                    #keyComparator: keyComparator,
                    #compactionStrategy: compactionStrategy,
                    #crashRecovery: crashRecovery,
                    #path: path,
                    #bytes: bytes,
                    #collection: collection,
                    #encryptionKey: encryptionKey,
                  },
                ),
              ),
            ),
          )
          as _i5.Future<_i3.Box<E>>);

  @override
  _i5.Future<_i3.LazyBox<E>> openLazyBox<E>(
    String? name, {
    _i3.HiveCipher? encryptionCipher,
    _i3.KeyComparator? keyComparator = _i7.defaultKeyComparator,
    _i3.CompactionStrategy? compactionStrategy = _i8.defaultCompactionStrategy,
    bool? crashRecovery = true,
    String? path,
    String? collection,
    List<int>? encryptionKey,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #openLazyBox,
              [name],
              {
                #encryptionCipher: encryptionCipher,
                #keyComparator: keyComparator,
                #compactionStrategy: compactionStrategy,
                #crashRecovery: crashRecovery,
                #path: path,
                #collection: collection,
                #encryptionKey: encryptionKey,
              },
            ),
            returnValue: _i5.Future<_i3.LazyBox<E>>.value(
              _FakeLazyBox_6<E>(
                this,
                Invocation.method(
                  #openLazyBox,
                  [name],
                  {
                    #encryptionCipher: encryptionCipher,
                    #keyComparator: keyComparator,
                    #compactionStrategy: compactionStrategy,
                    #crashRecovery: crashRecovery,
                    #path: path,
                    #collection: collection,
                    #encryptionKey: encryptionKey,
                  },
                ),
              ),
            ),
          )
          as _i5.Future<_i3.LazyBox<E>>);

  @override
  _i3.Box<E> box<E>(String? name) =>
      (super.noSuchMethod(
            Invocation.method(#box, [name]),
            returnValue: _FakeBox_5<E>(this, Invocation.method(#box, [name])),
          )
          as _i3.Box<E>);

  @override
  _i3.LazyBox<E> lazyBox<E>(String? name) =>
      (super.noSuchMethod(
            Invocation.method(#lazyBox, [name]),
            returnValue: _FakeLazyBox_6<E>(
              this,
              Invocation.method(#lazyBox, [name]),
            ),
          )
          as _i3.LazyBox<E>);

  @override
  bool isBoxOpen(String? name) =>
      (super.noSuchMethod(
            Invocation.method(#isBoxOpen, [name]),
            returnValue: false,
          )
          as bool);

  @override
  _i5.Future<void> close() =>
      (super.noSuchMethod(
            Invocation.method(#close, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteBoxFromDisk(String? name, {String? path}) =>
      (super.noSuchMethod(
            Invocation.method(#deleteBoxFromDisk, [name], {#path: path}),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  _i5.Future<void> deleteFromDisk() =>
      (super.noSuchMethod(
            Invocation.method(#deleteFromDisk, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  List<int> generateSecureKey() =>
      (super.noSuchMethod(
            Invocation.method(#generateSecureKey, []),
            returnValue: <int>[],
          )
          as List<int>);

  @override
  _i5.Future<bool> boxExists(String? name, {String? path}) =>
      (super.noSuchMethod(
            Invocation.method(#boxExists, [name], {#path: path}),
            returnValue: _i5.Future<bool>.value(false),
          )
          as _i5.Future<bool>);

  @override
  void resetAdapters() => super.noSuchMethod(
    Invocation.method(#resetAdapters, []),
    returnValueForMissingStub: null,
  );

  @override
  void registerAdapter<T>(
    _i3.TypeAdapter<T>? adapter, {
    bool? internal = false,
    bool? override = false,
  }) => super.noSuchMethod(
    Invocation.method(
      #registerAdapter,
      [adapter],
      {#internal: internal, #override: override},
    ),
    returnValueForMissingStub: null,
  );

  @override
  bool isAdapterRegistered(int? typeId) =>
      (super.noSuchMethod(
            Invocation.method(#isAdapterRegistered, [typeId]),
            returnValue: false,
          )
          as bool);

  @override
  void ignoreTypeId<T>(int? typeId) => super.noSuchMethod(
    Invocation.method(#ignoreTypeId, [typeId]),
    returnValueForMissingStub: null,
  );
}

/// A class which mocks [BoxCollection].
///
/// See the documentation for Mockito's code generation for more information.
class MockBoxCollection extends _i1.Mock implements _i3.BoxCollection {
  MockBoxCollection() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name =>
      (super.noSuchMethod(
            Invocation.getter(#name),
            returnValue: _i6.dummyValue<String>(this, Invocation.getter(#name)),
          )
          as String);

  @override
  Set<String> get boxNames =>
      (super.noSuchMethod(Invocation.getter(#boxNames), returnValue: <String>{})
          as Set<String>);

  @override
  _i5.Future<_i3.CollectionBox<V>> openBox<V>(
    String? name, {
    bool? preload = false,
    _i3.CollectionBox<V> Function(String, _i3.BoxCollection)? boxCreator,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #openBox,
              [name],
              {#preload: preload, #boxCreator: boxCreator},
            ),
            returnValue: _i5.Future<_i3.CollectionBox<V>>.value(
              _FakeCollectionBox_7<V>(
                this,
                Invocation.method(
                  #openBox,
                  [name],
                  {#preload: preload, #boxCreator: boxCreator},
                ),
              ),
            ),
          )
          as _i5.Future<_i3.CollectionBox<V>>);

  @override
  _i5.Future<void> transaction(
    _i5.Future<void> Function()? action, {
    List<String>? boxNames,
    bool? readOnly = false,
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #transaction,
              [action],
              {#boxNames: boxNames, #readOnly: readOnly},
            ),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);

  @override
  void close() => super.noSuchMethod(
    Invocation.method(#close, []),
    returnValueForMissingStub: null,
  );

  @override
  _i5.Future<void> deleteFromDisk() =>
      (super.noSuchMethod(
            Invocation.method(#deleteFromDisk, []),
            returnValue: _i5.Future<void>.value(),
            returnValueForMissingStub: _i5.Future<void>.value(),
          )
          as _i5.Future<void>);
}
