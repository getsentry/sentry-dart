// Mocks generated by Mockito 5.4.4 from annotations
// in sentry_flutter/test/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;

import 'package:flutter/src/services/binary_messenger.dart' as _i6;
import 'package:flutter/src/services/message_codec.dart' as _i5;
import 'package:flutter/src/services/platform_channel.dart' as _i11;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i9;
import 'package:sentry/sentry.dart' as _i2;
import 'package:sentry/src/profiling.dart' as _i10;
import 'package:sentry/src/protocol.dart' as _i3;
import 'package:sentry/src/sentry_envelope.dart' as _i8;
import 'package:sentry/src/sentry_tracer.dart' as _i4;

import 'mocks.dart' as _i12;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeSentrySpanContext_0 extends _i1.SmartFake
    implements _i2.SentrySpanContext {
  _FakeSentrySpanContext_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeDateTime_1 extends _i1.SmartFake implements DateTime {
  _FakeDateTime_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeISentrySpan_2 extends _i1.SmartFake implements _i2.ISentrySpan {
  _FakeISentrySpan_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryTraceHeader_3 extends _i1.SmartFake
    implements _i3.SentryTraceHeader {
  _FakeSentryTraceHeader_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryTracer_4 extends _i1.SmartFake implements _i4.SentryTracer {
  _FakeSentryTracer_4(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryId_5 extends _i1.SmartFake implements _i3.SentryId {
  _FakeSentryId_5(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeContexts_6 extends _i1.SmartFake implements _i3.Contexts {
  _FakeContexts_6(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryTransaction_7 extends _i1.SmartFake
    implements _i3.SentryTransaction {
  _FakeSentryTransaction_7(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeMethodCodec_8 extends _i1.SmartFake implements _i5.MethodCodec {
  _FakeMethodCodec_8(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeBinaryMessenger_9 extends _i1.SmartFake
    implements _i6.BinaryMessenger {
  _FakeBinaryMessenger_9(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeSentryOptions_10 extends _i1.SmartFake implements _i2.SentryOptions {
  _FakeSentryOptions_10(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeScope_11 extends _i1.SmartFake implements _i2.Scope {
  _FakeScope_11(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeHub_12 extends _i1.SmartFake implements _i2.Hub {
  _FakeHub_12(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [Transport].
///
/// See the documentation for Mockito's code generation for more information.
class MockTransport extends _i1.Mock implements _i2.Transport {
  MockTransport() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i7.Future<_i3.SentryId?> send(_i8.SentryEnvelope? envelope) =>
      (super.noSuchMethod(
        Invocation.method(
          #send,
          [envelope],
        ),
        returnValue: _i7.Future<_i3.SentryId?>.value(),
      ) as _i7.Future<_i3.SentryId?>);
}

/// A class which mocks [SentryTracer].
///
/// See the documentation for Mockito's code generation for more information.
class MockSentryTracer extends _i1.Mock implements _i4.SentryTracer {
  MockSentryTracer() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name => (super.noSuchMethod(
        Invocation.getter(#name),
        returnValue: _i9.dummyValue<String>(
          this,
          Invocation.getter(#name),
        ),
      ) as String);

  @override
  set name(String? _name) => super.noSuchMethod(
        Invocation.setter(
          #name,
          _name,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.SentryTransactionNameSource get transactionNameSource =>
      (super.noSuchMethod(
        Invocation.getter(#transactionNameSource),
        returnValue: _i3.SentryTransactionNameSource.custom,
      ) as _i3.SentryTransactionNameSource);

  @override
  set transactionNameSource(
          _i3.SentryTransactionNameSource? _transactionNameSource) =>
      super.noSuchMethod(
        Invocation.setter(
          #transactionNameSource,
          _transactionNameSource,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set profiler(_i10.SentryProfiler? _profiler) => super.noSuchMethod(
        Invocation.setter(
          #profiler,
          _profiler,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set profileInfo(_i10.SentryProfileInfo? _profileInfo) => super.noSuchMethod(
        Invocation.setter(
          #profileInfo,
          _profileInfo,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i2.SentrySpanContext get context => (super.noSuchMethod(
        Invocation.getter(#context),
        returnValue: _FakeSentrySpanContext_0(
          this,
          Invocation.getter(#context),
        ),
      ) as _i2.SentrySpanContext);

  @override
  set origin(String? origin) => super.noSuchMethod(
        Invocation.setter(
          #origin,
          origin,
        ),
        returnValueForMissingStub: null,
      );

  @override
  DateTime get startTimestamp => (super.noSuchMethod(
        Invocation.getter(#startTimestamp),
        returnValue: _FakeDateTime_1(
          this,
          Invocation.getter(#startTimestamp),
        ),
      ) as DateTime);

  @override
  Map<String, dynamic> get data => (super.noSuchMethod(
        Invocation.getter(#data),
        returnValue: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  bool get finished => (super.noSuchMethod(
        Invocation.getter(#finished),
        returnValue: false,
      ) as bool);

  @override
  List<_i3.SentrySpan> get children => (super.noSuchMethod(
        Invocation.getter(#children),
        returnValue: <_i3.SentrySpan>[],
      ) as List<_i3.SentrySpan>);

  @override
  set throwable(dynamic throwable) => super.noSuchMethod(
        Invocation.setter(
          #throwable,
          throwable,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set status(_i3.SpanStatus? status) => super.noSuchMethod(
        Invocation.setter(
          #status,
          status,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, String> get tags => (super.noSuchMethod(
        Invocation.getter(#tags),
        returnValue: <String, String>{},
      ) as Map<String, String>);

  @override
  Map<String, _i2.SentryMeasurement> get measurements => (super.noSuchMethod(
        Invocation.getter(#measurements),
        returnValue: <String, _i2.SentryMeasurement>{},
      ) as Map<String, _i2.SentryMeasurement>);

  @override
  _i7.Future<void> finish({
    _i3.SpanStatus? status,
    DateTime? endTimestamp,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #finish,
          [],
          {
            #status: status,
            #endTimestamp: endTimestamp,
          },
        ),
        returnValue: _i7.Future<void>.value(),
        returnValueForMissingStub: _i7.Future<void>.value(),
      ) as _i7.Future<void>);

  @override
  void removeData(String? key) => super.noSuchMethod(
        Invocation.method(
          #removeData,
          [key],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeTag(String? key) => super.noSuchMethod(
        Invocation.method(
          #removeTag,
          [key],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setData(
    String? key,
    dynamic value,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setData,
          [
            key,
            value,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setTag(
    String? key,
    String? value,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setTag,
          [
            key,
            value,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i2.ISentrySpan startChild(
    String? operation, {
    String? description,
    DateTime? startTimestamp,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startChild,
          [operation],
          {
            #description: description,
            #startTimestamp: startTimestamp,
          },
        ),
        returnValue: _FakeISentrySpan_2(
          this,
          Invocation.method(
            #startChild,
            [operation],
            {
              #description: description,
              #startTimestamp: startTimestamp,
            },
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  _i2.ISentrySpan startChildWithParentSpanId(
    _i3.SpanId? parentSpanId,
    String? operation, {
    String? description,
    DateTime? startTimestamp,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startChildWithParentSpanId,
          [
            parentSpanId,
            operation,
          ],
          {
            #description: description,
            #startTimestamp: startTimestamp,
          },
        ),
        returnValue: _FakeISentrySpan_2(
          this,
          Invocation.method(
            #startChildWithParentSpanId,
            [
              parentSpanId,
              operation,
            ],
            {
              #description: description,
              #startTimestamp: startTimestamp,
            },
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  _i3.SentryTraceHeader toSentryTrace() => (super.noSuchMethod(
        Invocation.method(
          #toSentryTrace,
          [],
        ),
        returnValue: _FakeSentryTraceHeader_3(
          this,
          Invocation.method(
            #toSentryTrace,
            [],
          ),
        ),
      ) as _i3.SentryTraceHeader);

  @override
  void setMeasurement(
    String? name,
    num? value, {
    _i2.SentryMeasurementUnit? unit,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #setMeasurement,
          [
            name,
            value,
          ],
          {#unit: unit},
        ),
        returnValueForMissingStub: null,
      );

  @override
  void scheduleFinish() => super.noSuchMethod(
        Invocation.method(
          #scheduleFinish,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [SentryTransaction].
///
/// See the documentation for Mockito's code generation for more information.
// ignore: must_be_immutable
class MockSentryTransaction extends _i1.Mock implements _i3.SentryTransaction {
  MockSentryTransaction() {
    _i1.throwOnMissingStub(this);
  }

  @override
  DateTime get startTimestamp => (super.noSuchMethod(
        Invocation.getter(#startTimestamp),
        returnValue: _FakeDateTime_1(
          this,
          Invocation.getter(#startTimestamp),
        ),
      ) as DateTime);

  @override
  set startTimestamp(DateTime? _startTimestamp) => super.noSuchMethod(
        Invocation.setter(
          #startTimestamp,
          _startTimestamp,
        ),
        returnValueForMissingStub: null,
      );

  @override
  List<_i3.SentrySpan> get spans => (super.noSuchMethod(
        Invocation.getter(#spans),
        returnValue: <_i3.SentrySpan>[],
      ) as List<_i3.SentrySpan>);

  @override
  set spans(List<_i3.SentrySpan>? _spans) => super.noSuchMethod(
        Invocation.setter(
          #spans,
          _spans,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i4.SentryTracer get tracer => (super.noSuchMethod(
        Invocation.getter(#tracer),
        returnValue: _FakeSentryTracer_4(
          this,
          Invocation.getter(#tracer),
        ),
      ) as _i4.SentryTracer);

  @override
  Map<String, _i2.SentryMeasurement> get measurements => (super.noSuchMethod(
        Invocation.getter(#measurements),
        returnValue: <String, _i2.SentryMeasurement>{},
      ) as Map<String, _i2.SentryMeasurement>);

  @override
  set measurements(Map<String, _i2.SentryMeasurement>? _measurements) =>
      super.noSuchMethod(
        Invocation.setter(
          #measurements,
          _measurements,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set transactionInfo(_i3.SentryTransactionInfo? _transactionInfo) =>
      super.noSuchMethod(
        Invocation.setter(
          #transactionInfo,
          _transactionInfo,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool get finished => (super.noSuchMethod(
        Invocation.getter(#finished),
        returnValue: false,
      ) as bool);

  @override
  bool get sampled => (super.noSuchMethod(
        Invocation.getter(#sampled),
        returnValue: false,
      ) as bool);

  @override
  _i3.SentryId get eventId => (super.noSuchMethod(
        Invocation.getter(#eventId),
        returnValue: _FakeSentryId_5(
          this,
          Invocation.getter(#eventId),
        ),
      ) as _i3.SentryId);

  @override
  _i3.Contexts get contexts => (super.noSuchMethod(
        Invocation.getter(#contexts),
        returnValue: _FakeContexts_6(
          this,
          Invocation.getter(#contexts),
        ),
      ) as _i3.Contexts);

  @override
  Map<String, dynamic> toJson() => (super.noSuchMethod(
        Invocation.method(
          #toJson,
          [],
        ),
        returnValue: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  _i3.SentryTransaction copyWith({
    _i3.SentryId? eventId,
    DateTime? timestamp,
    String? platform,
    String? logger,
    String? serverName,
    String? release,
    String? dist,
    String? environment,
    Map<String, String>? modules,
    _i3.SentryMessage? message,
    String? transaction,
    dynamic throwable,
    _i3.SentryLevel? level,
    String? culprit,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
    _i3.SentryUser? user,
    _i3.Contexts? contexts,
    List<_i3.Breadcrumb>? breadcrumbs,
    _i3.SdkVersion? sdk,
    _i3.SentryRequest? request,
    _i3.DebugMeta? debugMeta,
    List<_i3.SentryException>? exceptions,
    List<_i3.SentryThread>? threads,
    String? type,
    Map<String, _i2.SentryMeasurement>? measurements,
    Map<String, List<_i3.MetricSummary>>? metricSummaries,
    _i3.SentryTransactionInfo? transactionInfo,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #copyWith,
          [],
          {
            #eventId: eventId,
            #timestamp: timestamp,
            #platform: platform,
            #logger: logger,
            #serverName: serverName,
            #release: release,
            #dist: dist,
            #environment: environment,
            #modules: modules,
            #message: message,
            #transaction: transaction,
            #throwable: throwable,
            #level: level,
            #culprit: culprit,
            #tags: tags,
            #extra: extra,
            #fingerprint: fingerprint,
            #user: user,
            #contexts: contexts,
            #breadcrumbs: breadcrumbs,
            #sdk: sdk,
            #request: request,
            #debugMeta: debugMeta,
            #exceptions: exceptions,
            #threads: threads,
            #type: type,
            #measurements: measurements,
            #metricSummaries: metricSummaries,
            #transactionInfo: transactionInfo,
          },
        ),
        returnValue: _FakeSentryTransaction_7(
          this,
          Invocation.method(
            #copyWith,
            [],
            {
              #eventId: eventId,
              #timestamp: timestamp,
              #platform: platform,
              #logger: logger,
              #serverName: serverName,
              #release: release,
              #dist: dist,
              #environment: environment,
              #modules: modules,
              #message: message,
              #transaction: transaction,
              #throwable: throwable,
              #level: level,
              #culprit: culprit,
              #tags: tags,
              #extra: extra,
              #fingerprint: fingerprint,
              #user: user,
              #contexts: contexts,
              #breadcrumbs: breadcrumbs,
              #sdk: sdk,
              #request: request,
              #debugMeta: debugMeta,
              #exceptions: exceptions,
              #threads: threads,
              #type: type,
              #measurements: measurements,
              #transactionInfo: transactionInfo,
            },
          ),
        ),
      ) as _i3.SentryTransaction);
}

/// A class which mocks [SentrySpan].
///
/// See the documentation for Mockito's code generation for more information.
class MockSentrySpan extends _i1.Mock implements _i3.SentrySpan {
  MockSentrySpan() {
    _i1.throwOnMissingStub(this);
  }

  @override
  set status(_i3.SpanStatus? status) => super.noSuchMethod(
        Invocation.setter(
          #status,
          status,
        ),
        returnValueForMissingStub: null,
      );

  @override
  DateTime get startTimestamp => (super.noSuchMethod(
        Invocation.getter(#startTimestamp),
        returnValue: _FakeDateTime_1(
          this,
          Invocation.getter(#startTimestamp),
        ),
      ) as DateTime);

  @override
  _i2.SentrySpanContext get context => (super.noSuchMethod(
        Invocation.getter(#context),
        returnValue: _FakeSentrySpanContext_0(
          this,
          Invocation.getter(#context),
        ),
      ) as _i2.SentrySpanContext);

  @override
  set origin(String? origin) => super.noSuchMethod(
        Invocation.setter(
          #origin,
          origin,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool get finished => (super.noSuchMethod(
        Invocation.getter(#finished),
        returnValue: false,
      ) as bool);

  @override
  set throwable(dynamic throwable) => super.noSuchMethod(
        Invocation.setter(
          #throwable,
          throwable,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, String> get tags => (super.noSuchMethod(
        Invocation.getter(#tags),
        returnValue: <String, String>{},
      ) as Map<String, String>);

  @override
  Map<String, dynamic> get data => (super.noSuchMethod(
        Invocation.getter(#data),
        returnValue: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  _i7.Future<void> finish({
    _i3.SpanStatus? status,
    DateTime? endTimestamp,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #finish,
          [],
          {
            #status: status,
            #endTimestamp: endTimestamp,
          },
        ),
        returnValue: _i7.Future<void>.value(),
        returnValueForMissingStub: _i7.Future<void>.value(),
      ) as _i7.Future<void>);

  @override
  void removeData(String? key) => super.noSuchMethod(
        Invocation.method(
          #removeData,
          [key],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeTag(String? key) => super.noSuchMethod(
        Invocation.method(
          #removeTag,
          [key],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setData(
    String? key,
    dynamic value,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setData,
          [
            key,
            value,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setTag(
    String? key,
    String? value,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setTag,
          [
            key,
            value,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i2.ISentrySpan startChild(
    String? operation, {
    String? description,
    DateTime? startTimestamp,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startChild,
          [operation],
          {
            #description: description,
            #startTimestamp: startTimestamp,
          },
        ),
        returnValue: _FakeISentrySpan_2(
          this,
          Invocation.method(
            #startChild,
            [operation],
            {
              #description: description,
              #startTimestamp: startTimestamp,
            },
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  Map<String, dynamic> toJson() => (super.noSuchMethod(
        Invocation.method(
          #toJson,
          [],
        ),
        returnValue: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  _i3.SentryTraceHeader toSentryTrace() => (super.noSuchMethod(
        Invocation.method(
          #toSentryTrace,
          [],
        ),
        returnValue: _FakeSentryTraceHeader_3(
          this,
          Invocation.method(
            #toSentryTrace,
            [],
          ),
        ),
      ) as _i3.SentryTraceHeader);

  @override
  void setMeasurement(
    String? name,
    num? value, {
    _i2.SentryMeasurementUnit? unit,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #setMeasurement,
          [
            name,
            value,
          ],
          {#unit: unit},
        ),
        returnValueForMissingStub: null,
      );

  @override
  void scheduleFinish() => super.noSuchMethod(
        Invocation.method(
          #scheduleFinish,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [MethodChannel].
///
/// See the documentation for Mockito's code generation for more information.
class MockMethodChannel extends _i1.Mock implements _i11.MethodChannel {
  MockMethodChannel() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name => (super.noSuchMethod(
        Invocation.getter(#name),
        returnValue: _i9.dummyValue<String>(
          this,
          Invocation.getter(#name),
        ),
      ) as String);

  @override
  _i5.MethodCodec get codec => (super.noSuchMethod(
        Invocation.getter(#codec),
        returnValue: _FakeMethodCodec_8(
          this,
          Invocation.getter(#codec),
        ),
      ) as _i5.MethodCodec);

  @override
  _i6.BinaryMessenger get binaryMessenger => (super.noSuchMethod(
        Invocation.getter(#binaryMessenger),
        returnValue: _FakeBinaryMessenger_9(
          this,
          Invocation.getter(#binaryMessenger),
        ),
      ) as _i6.BinaryMessenger);

  @override
  _i7.Future<T?> invokeMethod<T>(
    String? method, [
    dynamic arguments,
  ]) =>
      (super.noSuchMethod(
        Invocation.method(
          #invokeMethod,
          [
            method,
            arguments,
          ],
        ),
        returnValue: _i7.Future<T?>.value(),
      ) as _i7.Future<T?>);

  @override
  _i7.Future<List<T>?> invokeListMethod<T>(
    String? method, [
    dynamic arguments,
  ]) =>
      (super.noSuchMethod(
        Invocation.method(
          #invokeListMethod,
          [
            method,
            arguments,
          ],
        ),
        returnValue: _i7.Future<List<T>?>.value(),
      ) as _i7.Future<List<T>?>);

  @override
  _i7.Future<Map<K, V>?> invokeMapMethod<K, V>(
    String? method, [
    dynamic arguments,
  ]) =>
      (super.noSuchMethod(
        Invocation.method(
          #invokeMapMethod,
          [
            method,
            arguments,
          ],
        ),
        returnValue: _i7.Future<Map<K, V>?>.value(),
      ) as _i7.Future<Map<K, V>?>);

  @override
  void setMethodCallHandler(
          _i7.Future<dynamic> Function(_i5.MethodCall)? handler) =>
      super.noSuchMethod(
        Invocation.method(
          #setMethodCallHandler,
          [handler],
        ),
        returnValueForMissingStub: null,
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
        returnValue: _FakeSentryOptions_10(
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
  _i3.SentryId get lastEventId => (super.noSuchMethod(
        Invocation.getter(#lastEventId),
        returnValue: _FakeSentryId_5(
          this,
          Invocation.getter(#lastEventId),
        ),
      ) as _i3.SentryId);

  @override
  _i2.Scope get scope => (super.noSuchMethod(
        Invocation.getter(#scope),
        returnValue: _FakeScope_11(
          this,
          Invocation.getter(#scope),
        ),
      ) as _i2.Scope);

  @override
  set profilerFactory(_i10.SentryProfilerFactory? value) => super.noSuchMethod(
        Invocation.setter(
          #profilerFactory,
          value,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i7.Future<_i3.SentryId> captureEvent(
    _i3.SentryEvent? event, {
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
        returnValue: _i7.Future<_i3.SentryId>.value(_FakeSentryId_5(
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
      ) as _i7.Future<_i3.SentryId>);

  @override
  _i7.Future<_i3.SentryId> captureException(
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
        returnValue: _i7.Future<_i3.SentryId>.value(_FakeSentryId_5(
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
      ) as _i7.Future<_i3.SentryId>);

  @override
  _i7.Future<_i3.SentryId> captureMessage(
    String? message, {
    _i3.SentryLevel? level,
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
        returnValue: _i7.Future<_i3.SentryId>.value(_FakeSentryId_5(
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
      ) as _i7.Future<_i3.SentryId>);

  @override
  _i7.Future<void> captureUserFeedback(_i2.SentryUserFeedback? userFeedback) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureUserFeedback,
          [userFeedback],
        ),
        returnValue: _i7.Future<void>.value(),
        returnValueForMissingStub: _i7.Future<void>.value(),
      ) as _i7.Future<void>);

  @override
  _i7.Future<void> addBreadcrumb(
    _i3.Breadcrumb? crumb, {
    _i2.Hint? hint,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #addBreadcrumb,
          [crumb],
          {#hint: hint},
        ),
        returnValue: _i7.Future<void>.value(),
        returnValueForMissingStub: _i7.Future<void>.value(),
      ) as _i7.Future<void>);

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
        returnValue: _FakeHub_12(
          this,
          Invocation.method(
            #clone,
            [],
          ),
        ),
      ) as _i2.Hub);

  @override
  _i7.Future<void> close() => (super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValue: _i7.Future<void>.value(),
        returnValueForMissingStub: _i7.Future<void>.value(),
      ) as _i7.Future<void>);

  @override
  _i7.FutureOr<void> configureScope(_i2.ScopeCallback? callback) =>
      (super.noSuchMethod(Invocation.method(
        #configureScope,
        [callback],
      )) as _i7.FutureOr<void>);

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
        returnValue: _i12.startTransactionShim(
          name,
          operation,
          description: description,
          startTimestamp: startTimestamp,
          bindToScope: bindToScope,
          waitForChildren: waitForChildren,
          autoFinishAfter: autoFinishAfter,
          trimEnd: trimEnd,
          onFinish: onFinish,
          customSamplingContext: customSamplingContext,
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
        returnValue: _FakeISentrySpan_2(
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
  _i7.Future<_i3.SentryId> captureTransaction(
    _i3.SentryTransaction? transaction, {
    _i2.SentryTraceContextHeader? traceContext,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #captureTransaction,
          [transaction],
          {#traceContext: traceContext},
        ),
        returnValue: _i7.Future<_i3.SentryId>.value(_FakeSentryId_5(
          this,
          Invocation.method(
            #captureTransaction,
            [transaction],
            {#traceContext: traceContext},
          ),
        )),
      ) as _i7.Future<_i3.SentryId>);

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
