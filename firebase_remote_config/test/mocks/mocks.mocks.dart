// Mocks generated by Mockito 5.4.6 from annotations
// in sentry_firebase_remote_config/test/mocks/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;

import 'package:firebase_core/firebase_core.dart' as _i3;
import 'package:firebase_remote_config/firebase_remote_config.dart' as _i7;
import 'package:firebase_remote_config_platform_interface/firebase_remote_config_platform_interface.dart'
    as _i4;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i8;
import 'package:sentry/sentry.dart' as _i2;
import 'package:sentry/src/profiling.dart' as _i6;

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

class _FakeFirebaseApp_5 extends _i1.SmartFake implements _i3.FirebaseApp {
  _FakeFirebaseApp_5(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeDateTime_6 extends _i1.SmartFake implements DateTime {
  _FakeDateTime_6(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeRemoteConfigSettings_7 extends _i1.SmartFake
    implements _i4.RemoteConfigSettings {
  _FakeRemoteConfigSettings_7(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeRemoteConfigValue_8 extends _i1.SmartFake
    implements _i4.RemoteConfigValue {
  _FakeRemoteConfigValue_8(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeFuture_9<T1> extends _i1.SmartFake implements _i5.Future<T1> {
  _FakeFuture_9(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeStreamSubscription_10<T1> extends _i1.SmartFake
    implements _i5.StreamSubscription<T1> {
  _FakeStreamSubscription_10(
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
  set profilerFactory(_i6.SentryProfilerFactory? value) => super.noSuchMethod(
        Invocation.setter(
          #profilerFactory,
          value,
        ),
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
          {
            #stackTrace: stackTrace,
            #hint: hint,
            #withScope: withScope,
          },
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(_FakeSentryId_1(
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
      ) as _i5.Future<_i2.SentryId>);

  @override
  _i5.Future<_i2.SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    _i2.Hint? hint,
    _i2.SentryMessage? message,
    _i2.ScopeCallback? withScope,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureException,
          [throwable],
          {
            #stackTrace: stackTrace,
            #hint: hint,
            #message: message,
            #withScope: withScope,
          },
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(_FakeSentryId_1(
          this,
          Invocation.method(
            #captureException,
            [throwable],
            {
              #stackTrace: stackTrace,
              #hint: hint,
              #message: message,
              #withScope: withScope,
            },
          ),
        )),
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
        returnValue: _i5.Future<_i2.SentryId>.value(_FakeSentryId_1(
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
          {
            #hint: hint,
            #withScope: withScope,
          },
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(_FakeSentryId_1(
          this,
          Invocation.method(
            #captureFeedback,
            [feedback],
            {
              #hint: hint,
              #withScope: withScope,
            },
          ),
        )),
      ) as _i5.Future<_i2.SentryId>);

  @override
  _i5.FutureOr<void> captureLog(_i2.SentryLog? log) =>
      (super.noSuchMethod(Invocation.method(
        #captureLog,
        [log],
      )) as _i5.FutureOr<void>);

  @override
  _i5.Future<void> addBreadcrumb(
    _i2.Breadcrumb? crumb, {
    _i2.Hint? hint,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #addBreadcrumb,
          [crumb],
          {#hint: hint},
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

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
  _i5.Future<void> close() => (super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.FutureOr<void> configureScope(_i2.ScopeCallback? callback) =>
      (super.noSuchMethod(Invocation.method(
        #configureScope,
        [callback],
      )) as _i5.FutureOr<void>);

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
  void generateNewTrace() => super.noSuchMethod(
        Invocation.method(
          #generateNewTrace,
          [],
        ),
        returnValueForMissingStub: null,
      );

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
          {
            #traceContext: traceContext,
            #hint: hint,
          },
        ),
        returnValue: _i5.Future<_i2.SentryId>.value(_FakeSentryId_1(
          this,
          Invocation.method(
            #captureTransaction,
            [transaction],
            {
              #traceContext: traceContext,
              #hint: hint,
            },
          ),
        )),
      ) as _i5.Future<_i2.SentryId>);

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

/// A class which mocks [FirebaseRemoteConfig].
///
/// See the documentation for Mockito's code generation for more information.
class MockFirebaseRemoteConfig extends _i1.Mock
    implements _i7.FirebaseRemoteConfig {
  MockFirebaseRemoteConfig() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.FirebaseApp get app => (super.noSuchMethod(
        Invocation.getter(#app),
        returnValue: _FakeFirebaseApp_5(
          this,
          Invocation.getter(#app),
        ),
      ) as _i3.FirebaseApp);

  @override
  DateTime get lastFetchTime => (super.noSuchMethod(
        Invocation.getter(#lastFetchTime),
        returnValue: _FakeDateTime_6(
          this,
          Invocation.getter(#lastFetchTime),
        ),
      ) as DateTime);

  @override
  _i4.RemoteConfigFetchStatus get lastFetchStatus => (super.noSuchMethod(
        Invocation.getter(#lastFetchStatus),
        returnValue: _i4.RemoteConfigFetchStatus.noFetchYet,
      ) as _i4.RemoteConfigFetchStatus);

  @override
  _i4.RemoteConfigSettings get settings => (super.noSuchMethod(
        Invocation.getter(#settings),
        returnValue: _FakeRemoteConfigSettings_7(
          this,
          Invocation.getter(#settings),
        ),
      ) as _i4.RemoteConfigSettings);

  @override
  _i5.Stream<_i4.RemoteConfigUpdate> get onConfigUpdated => (super.noSuchMethod(
        Invocation.getter(#onConfigUpdated),
        returnValue: _i5.Stream<_i4.RemoteConfigUpdate>.empty(),
      ) as _i5.Stream<_i4.RemoteConfigUpdate>);

  @override
  Map<dynamic, dynamic> get pluginConstants => (super.noSuchMethod(
        Invocation.getter(#pluginConstants),
        returnValue: <dynamic, dynamic>{},
      ) as Map<dynamic, dynamic>);

  @override
  _i5.Future<bool> activate() => (super.noSuchMethod(
        Invocation.method(
          #activate,
          [],
        ),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<void> ensureInitialized() => (super.noSuchMethod(
        Invocation.method(
          #ensureInitialized,
          [],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<void> fetch() => (super.noSuchMethod(
        Invocation.method(
          #fetch,
          [],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<bool> fetchAndActivate() => (super.noSuchMethod(
        Invocation.method(
          #fetchAndActivate,
          [],
        ),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  Map<String, _i4.RemoteConfigValue> getAll() => (super.noSuchMethod(
        Invocation.method(
          #getAll,
          [],
        ),
        returnValue: <String, _i4.RemoteConfigValue>{},
      ) as Map<String, _i4.RemoteConfigValue>);

  @override
  bool getBool(String? key) => (super.noSuchMethod(
        Invocation.method(
          #getBool,
          [key],
        ),
        returnValue: false,
      ) as bool);

  @override
  int getInt(String? key) => (super.noSuchMethod(
        Invocation.method(
          #getInt,
          [key],
        ),
        returnValue: 0,
      ) as int);

  @override
  double getDouble(String? key) => (super.noSuchMethod(
        Invocation.method(
          #getDouble,
          [key],
        ),
        returnValue: 0.0,
      ) as double);

  @override
  String getString(String? key) => (super.noSuchMethod(
        Invocation.method(
          #getString,
          [key],
        ),
        returnValue: _i8.dummyValue<String>(
          this,
          Invocation.method(
            #getString,
            [key],
          ),
        ),
      ) as String);

  @override
  _i4.RemoteConfigValue getValue(String? key) => (super.noSuchMethod(
        Invocation.method(
          #getValue,
          [key],
        ),
        returnValue: _FakeRemoteConfigValue_8(
          this,
          Invocation.method(
            #getValue,
            [key],
          ),
        ),
      ) as _i4.RemoteConfigValue);

  @override
  _i5.Future<void> setConfigSettings(
          _i4.RemoteConfigSettings? remoteConfigSettings) =>
      (super.noSuchMethod(
        Invocation.method(
          #setConfigSettings,
          [remoteConfigSettings],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<void> setDefaults(Map<String, dynamic>? defaultParameters) =>
      (super.noSuchMethod(
        Invocation.method(
          #setDefaults,
          [defaultParameters],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<void> setCustomSignals(Map<String, Object?>? customSignals) =>
      (super.noSuchMethod(
        Invocation.method(
          #setCustomSignals,
          [customSignals],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);
}

/// A class which mocks [Stream].
///
/// See the documentation for Mockito's code generation for more information.
class MockStream<T> extends _i1.Mock implements _i5.Stream<T> {
  MockStream() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isBroadcast => (super.noSuchMethod(
        Invocation.getter(#isBroadcast),
        returnValue: false,
      ) as bool);

  @override
  _i5.Future<int> get length => (super.noSuchMethod(
        Invocation.getter(#length),
        returnValue: _i5.Future<int>.value(0),
      ) as _i5.Future<int>);

  @override
  _i5.Future<bool> get isEmpty => (super.noSuchMethod(
        Invocation.getter(#isEmpty),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<T> get first => (super.noSuchMethod(
        Invocation.getter(#first),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.getter(#first),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.getter(#first),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Future<T> get last => (super.noSuchMethod(
        Invocation.getter(#last),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.getter(#last),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.getter(#last),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Future<T> get single => (super.noSuchMethod(
        Invocation.getter(#single),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.getter(#single),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.getter(#single),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Stream<T> asBroadcastStream({
    void Function(_i5.StreamSubscription<T>)? onListen,
    void Function(_i5.StreamSubscription<T>)? onCancel,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #asBroadcastStream,
          [],
          {
            #onListen: onListen,
            #onCancel: onCancel,
          },
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #listen,
          [onData],
          {
            #onError: onError,
            #onDone: onDone,
            #cancelOnError: cancelOnError,
          },
        ),
        returnValue: _FakeStreamSubscription_10<T>(
          this,
          Invocation.method(
            #listen,
            [onData],
            {
              #onError: onError,
              #onDone: onDone,
              #cancelOnError: cancelOnError,
            },
          ),
        ),
      ) as _i5.StreamSubscription<T>);

  @override
  _i5.Stream<T> where(bool Function(T)? test) => (super.noSuchMethod(
        Invocation.method(
          #where,
          [test],
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Stream<S> map<S>(S Function(T)? convert) => (super.noSuchMethod(
        Invocation.method(
          #map,
          [convert],
        ),
        returnValue: _i5.Stream<S>.empty(),
      ) as _i5.Stream<S>);

  @override
  _i5.Stream<E> asyncMap<E>(_i5.FutureOr<E> Function(T)? convert) =>
      (super.noSuchMethod(
        Invocation.method(
          #asyncMap,
          [convert],
        ),
        returnValue: _i5.Stream<E>.empty(),
      ) as _i5.Stream<E>);

  @override
  _i5.Stream<E> asyncExpand<E>(_i5.Stream<E>? Function(T)? convert) =>
      (super.noSuchMethod(
        Invocation.method(
          #asyncExpand,
          [convert],
        ),
        returnValue: _i5.Stream<E>.empty(),
      ) as _i5.Stream<E>);

  @override
  _i5.Stream<T> handleError(
    Function? onError, {
    bool Function(dynamic)? test,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #handleError,
          [onError],
          {#test: test},
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Stream<S> expand<S>(Iterable<S> Function(T)? convert) =>
      (super.noSuchMethod(
        Invocation.method(
          #expand,
          [convert],
        ),
        returnValue: _i5.Stream<S>.empty(),
      ) as _i5.Stream<S>);

  @override
  _i5.Future<dynamic> pipe(_i5.StreamConsumer<T>? streamConsumer) =>
      (super.noSuchMethod(
        Invocation.method(
          #pipe,
          [streamConsumer],
        ),
        returnValue: _i5.Future<dynamic>.value(),
      ) as _i5.Future<dynamic>);

  @override
  _i5.Stream<S> transform<S>(_i5.StreamTransformer<T, S>? streamTransformer) =>
      (super.noSuchMethod(
        Invocation.method(
          #transform,
          [streamTransformer],
        ),
        returnValue: _i5.Stream<S>.empty(),
      ) as _i5.Stream<S>);

  @override
  _i5.Future<T> reduce(
          T Function(
            T,
            T,
          )? combine) =>
      (super.noSuchMethod(
        Invocation.method(
          #reduce,
          [combine],
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #reduce,
                  [combine],
                ),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.method(
                #reduce,
                [combine],
              ),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Future<S> fold<S>(
    S? initialValue,
    S Function(
      S,
      T,
    )? combine,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #fold,
          [
            initialValue,
            combine,
          ],
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<S>(
                this,
                Invocation.method(
                  #fold,
                  [
                    initialValue,
                    combine,
                  ],
                ),
              ),
              (S v) => _i5.Future<S>.value(v),
            ) ??
            _FakeFuture_9<S>(
              this,
              Invocation.method(
                #fold,
                [
                  initialValue,
                  combine,
                ],
              ),
            ),
      ) as _i5.Future<S>);

  @override
  _i5.Future<String> join([String? separator = '']) => (super.noSuchMethod(
        Invocation.method(
          #join,
          [separator],
        ),
        returnValue: _i5.Future<String>.value(_i8.dummyValue<String>(
          this,
          Invocation.method(
            #join,
            [separator],
          ),
        )),
      ) as _i5.Future<String>);

  @override
  _i5.Future<bool> contains(Object? needle) => (super.noSuchMethod(
        Invocation.method(
          #contains,
          [needle],
        ),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<void> forEach(void Function(T)? action) => (super.noSuchMethod(
        Invocation.method(
          #forEach,
          [action],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  _i5.Future<bool> every(bool Function(T)? test) => (super.noSuchMethod(
        Invocation.method(
          #every,
          [test],
        ),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Future<bool> any(bool Function(T)? test) => (super.noSuchMethod(
        Invocation.method(
          #any,
          [test],
        ),
        returnValue: _i5.Future<bool>.value(false),
      ) as _i5.Future<bool>);

  @override
  _i5.Stream<R> cast<R>() => (super.noSuchMethod(
        Invocation.method(
          #cast,
          [],
        ),
        returnValue: _i5.Stream<R>.empty(),
      ) as _i5.Stream<R>);

  @override
  _i5.Future<List<T>> toList() => (super.noSuchMethod(
        Invocation.method(
          #toList,
          [],
        ),
        returnValue: _i5.Future<List<T>>.value(<T>[]),
      ) as _i5.Future<List<T>>);

  @override
  _i5.Future<Set<T>> toSet() => (super.noSuchMethod(
        Invocation.method(
          #toSet,
          [],
        ),
        returnValue: _i5.Future<Set<T>>.value(<T>{}),
      ) as _i5.Future<Set<T>>);

  @override
  _i5.Future<E> drain<E>([E? futureValue]) => (super.noSuchMethod(
        Invocation.method(
          #drain,
          [futureValue],
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<E>(
                this,
                Invocation.method(
                  #drain,
                  [futureValue],
                ),
              ),
              (E v) => _i5.Future<E>.value(v),
            ) ??
            _FakeFuture_9<E>(
              this,
              Invocation.method(
                #drain,
                [futureValue],
              ),
            ),
      ) as _i5.Future<E>);

  @override
  _i5.Stream<T> take(int? count) => (super.noSuchMethod(
        Invocation.method(
          #take,
          [count],
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Stream<T> takeWhile(bool Function(T)? test) => (super.noSuchMethod(
        Invocation.method(
          #takeWhile,
          [test],
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Stream<T> skip(int? count) => (super.noSuchMethod(
        Invocation.method(
          #skip,
          [count],
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Stream<T> skipWhile(bool Function(T)? test) => (super.noSuchMethod(
        Invocation.method(
          #skipWhile,
          [test],
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Stream<T> distinct(
          [bool Function(
            T,
            T,
          )? equals]) =>
      (super.noSuchMethod(
        Invocation.method(
          #distinct,
          [equals],
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);

  @override
  _i5.Future<T> firstWhere(
    bool Function(T)? test, {
    T Function()? orElse,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #firstWhere,
          [test],
          {#orElse: orElse},
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #firstWhere,
                  [test],
                  {#orElse: orElse},
                ),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.method(
                #firstWhere,
                [test],
                {#orElse: orElse},
              ),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Future<T> lastWhere(
    bool Function(T)? test, {
    T Function()? orElse,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #lastWhere,
          [test],
          {#orElse: orElse},
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #lastWhere,
                  [test],
                  {#orElse: orElse},
                ),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.method(
                #lastWhere,
                [test],
                {#orElse: orElse},
              ),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Future<T> singleWhere(
    bool Function(T)? test, {
    T Function()? orElse,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #singleWhere,
          [test],
          {#orElse: orElse},
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #singleWhere,
                  [test],
                  {#orElse: orElse},
                ),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.method(
                #singleWhere,
                [test],
                {#orElse: orElse},
              ),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Future<T> elementAt(int? index) => (super.noSuchMethod(
        Invocation.method(
          #elementAt,
          [index],
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #elementAt,
                  [index],
                ),
              ),
              (T v) => _i5.Future<T>.value(v),
            ) ??
            _FakeFuture_9<T>(
              this,
              Invocation.method(
                #elementAt,
                [index],
              ),
            ),
      ) as _i5.Future<T>);

  @override
  _i5.Stream<T> timeout(
    Duration? timeLimit, {
    void Function(_i5.EventSink<T>)? onTimeout,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #timeout,
          [timeLimit],
          {#onTimeout: onTimeout},
        ),
        returnValue: _i5.Stream<T>.empty(),
      ) as _i5.Stream<T>);
}

/// A class which mocks [StreamSubscription].
///
/// See the documentation for Mockito's code generation for more information.
class MockStreamSubscription<T> extends _i1.Mock
    implements _i5.StreamSubscription<T> {
  MockStreamSubscription() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isPaused => (super.noSuchMethod(
        Invocation.getter(#isPaused),
        returnValue: false,
      ) as bool);

  @override
  _i5.Future<void> cancel() => (super.noSuchMethod(
        Invocation.method(
          #cancel,
          [],
        ),
        returnValue: _i5.Future<void>.value(),
        returnValueForMissingStub: _i5.Future<void>.value(),
      ) as _i5.Future<void>);

  @override
  void onData(void Function(T)? handleData) => super.noSuchMethod(
        Invocation.method(
          #onData,
          [handleData],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void onError(Function? handleError) => super.noSuchMethod(
        Invocation.method(
          #onError,
          [handleError],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void onDone(void Function()? handleDone) => super.noSuchMethod(
        Invocation.method(
          #onDone,
          [handleDone],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void pause([_i5.Future<void>? resumeSignal]) => super.noSuchMethod(
        Invocation.method(
          #pause,
          [resumeSignal],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void resume() => super.noSuchMethod(
        Invocation.method(
          #resume,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i5.Future<E> asFuture<E>([E? futureValue]) => (super.noSuchMethod(
        Invocation.method(
          #asFuture,
          [futureValue],
        ),
        returnValue: _i8.ifNotNull(
              _i8.dummyValueOrNull<E>(
                this,
                Invocation.method(
                  #asFuture,
                  [futureValue],
                ),
              ),
              (E v) => _i5.Future<E>.value(v),
            ) ??
            _FakeFuture_9<E>(
              this,
              Invocation.method(
                #asFuture,
                [futureValue],
              ),
            ),
      ) as _i5.Future<E>);
}
