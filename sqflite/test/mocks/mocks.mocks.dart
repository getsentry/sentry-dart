// Mocks generated by Mockito 5.4.5 from annotations
// in sentry_sqflite/test/mocks/mocks.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i6;
import 'package:sentry/sentry.dart' as _i2;
import 'package:sentry/src/profiling.dart' as _i7;
import 'package:sentry/src/sentry_tracer.dart' as _i5;
import 'package:sqflite_common/sql.dart' as _i8;
import 'package:sqflite_common/sqlite_api.dart' as _i3;

import 'mocks.dart' as _i9;

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

class _FakeSentrySpanContext_0 extends _i1.SmartFake
    implements _i2.SentrySpanContext {
  _FakeSentrySpanContext_0(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeDateTime_1 extends _i1.SmartFake implements DateTime {
  _FakeDateTime_1(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeISentrySpan_2 extends _i1.SmartFake implements _i2.ISentrySpan {
  _FakeISentrySpan_2(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeSentryTraceHeader_3 extends _i1.SmartFake
    implements _i2.SentryTraceHeader {
  _FakeSentryTraceHeader_3(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeDatabase_4 extends _i1.SmartFake implements _i3.Database {
  _FakeDatabase_4(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeFuture_5<T1> extends _i1.SmartFake implements _i4.Future<T1> {
  _FakeFuture_5(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeQueryCursor_6 extends _i1.SmartFake implements _i3.QueryCursor {
  _FakeQueryCursor_6(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeBatch_7 extends _i1.SmartFake implements _i3.Batch {
  _FakeBatch_7(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeSentryOptions_8 extends _i1.SmartFake implements _i2.SentryOptions {
  _FakeSentryOptions_8(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeSentryId_9 extends _i1.SmartFake implements _i2.SentryId {
  _FakeSentryId_9(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeScope_10 extends _i1.SmartFake implements _i2.Scope {
  _FakeScope_10(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

class _FakeHub_11 extends _i1.SmartFake implements _i2.Hub {
  _FakeHub_11(Object parent, Invocation parentInvocation)
      : super(parent, parentInvocation);
}

/// A class which mocks [SentryTracer].
///
/// See the documentation for Mockito's code generation for more information.
// ignore: invalid_use_of_internal_member
class MockSentryTracer extends _i1.Mock implements _i5.SentryTracer {
  MockSentryTracer() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get name => (super.noSuchMethod(
        Invocation.getter(#name),
        returnValue: _i6.dummyValue<String>(this, Invocation.getter(#name)),
      ) as String);

  @override
  set name(String? _name) => super.noSuchMethod(
        Invocation.setter(#name, _name),
        returnValueForMissingStub: null,
      );

  @override
  _i2.SentryTransactionNameSource get transactionNameSource =>
      (super.noSuchMethod(
        Invocation.getter(#transactionNameSource),
        returnValue: _i2.SentryTransactionNameSource.custom,
      ) as _i2.SentryTransactionNameSource);

  @override
  set transactionNameSource(
    _i2.SentryTransactionNameSource? _transactionNameSource,
  ) =>
      super.noSuchMethod(
        Invocation.setter(#transactionNameSource, _transactionNameSource),
        returnValueForMissingStub: null,
      );

  @override
  // ignore: invalid_use_of_internal_member
  set profiler(_i7.SentryProfiler? _profiler) => super.noSuchMethod(
        Invocation.setter(#profiler, _profiler),
        returnValueForMissingStub: null,
      );

  @override
  // ignore: invalid_use_of_internal_member
  set profileInfo(_i7.SentryProfileInfo? _profileInfo) => super.noSuchMethod(
        Invocation.setter(#profileInfo, _profileInfo),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, _i2.SentryMeasurement> get measurements => (super.noSuchMethod(
        Invocation.getter(#measurements),
        returnValue: <String, _i2.SentryMeasurement>{},
      ) as Map<String, _i2.SentryMeasurement>);

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
        Invocation.setter(#origin, origin),
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
  bool get finished =>
      (super.noSuchMethod(Invocation.getter(#finished), returnValue: false)
          as bool);

  @override
  List<_i2.SentrySpan> get children => (super.noSuchMethod(
        Invocation.getter(#children),
        returnValue: <_i2.SentrySpan>[],
      ) as List<_i2.SentrySpan>);

  @override
  set throwable(dynamic throwable) => super.noSuchMethod(
        Invocation.setter(#throwable, throwable),
        returnValueForMissingStub: null,
      );

  @override
  set status(_i2.SpanStatus? status) => super.noSuchMethod(
        Invocation.setter(#status, status),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, String> get tags => (super.noSuchMethod(
        Invocation.getter(#tags),
        returnValue: <String, String>{},
      ) as Map<String, String>);

  @override
  _i4.Future<void> finish({
    _i2.SpanStatus? status,
    DateTime? endTimestamp,
    _i2.Hint? hint,
  }) =>
      (super.noSuchMethod(
        Invocation.method(#finish, [], {
          #status: status,
          #endTimestamp: endTimestamp,
          #hint: hint,
        }),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  void removeData(String? key) => super.noSuchMethod(
        Invocation.method(#removeData, [key]),
        returnValueForMissingStub: null,
      );

  @override
  void removeTag(String? key) => super.noSuchMethod(
        Invocation.method(#removeTag, [key]),
        returnValueForMissingStub: null,
      );

  @override
  void setData(String? key, dynamic value) => super.noSuchMethod(
        Invocation.method(#setData, [key, value]),
        returnValueForMissingStub: null,
      );

  @override
  void setTag(String? key, String? value) => super.noSuchMethod(
        Invocation.method(#setTag, [key, value]),
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
          {#description: description, #startTimestamp: startTimestamp},
        ),
        returnValue: _FakeISentrySpan_2(
          this,
          Invocation.method(
            #startChild,
            [operation],
            {#description: description, #startTimestamp: startTimestamp},
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  _i2.ISentrySpan startChildWithParentSpanId(
    _i2.SpanId? parentSpanId,
    String? operation, {
    String? description,
    DateTime? startTimestamp,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startChildWithParentSpanId,
          [parentSpanId, operation],
          {#description: description, #startTimestamp: startTimestamp},
        ),
        returnValue: _FakeISentrySpan_2(
          this,
          Invocation.method(
            #startChildWithParentSpanId,
            [parentSpanId, operation],
            {#description: description, #startTimestamp: startTimestamp},
          ),
        ),
      ) as _i2.ISentrySpan);

  @override
  _i2.SentryTraceHeader toSentryTrace() => (super.noSuchMethod(
        Invocation.method(#toSentryTrace, []),
        returnValue: _FakeSentryTraceHeader_3(
          this,
          Invocation.method(#toSentryTrace, []),
        ),
      ) as _i2.SentryTraceHeader);

  @override
  void setMeasurement(
    String? name,
    num? value, {
    _i2.SentryMeasurementUnit? unit,
  }) =>
      super.noSuchMethod(
        Invocation.method(#setMeasurement, [name, value], {#unit: unit}),
        returnValueForMissingStub: null,
      );

  @override
  void setMeasurementFromChild(
    String? name,
    num? value, {
    _i2.SentryMeasurementUnit? unit,
  }) =>
      super.noSuchMethod(
        Invocation.method(
            #setMeasurementFromChild, [name, value], {#unit: unit}),
        returnValueForMissingStub: null,
      );

  @override
  void scheduleFinish() => super.noSuchMethod(
        Invocation.method(#scheduleFinish, []),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [Batch].
///
/// See the documentation for Mockito's code generation for more information.
class MockBatch extends _i1.Mock implements _i3.Batch {
  MockBatch() {
    _i1.throwOnMissingStub(this);
  }

  @override
  int get length =>
      (super.noSuchMethod(Invocation.getter(#length), returnValue: 0) as int);

  @override
  _i4.Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) =>
      (super.noSuchMethod(
        Invocation.method(#commit, [], {
          #exclusive: exclusive,
          #noResult: noResult,
          #continueOnError: continueOnError,
        }),
        returnValue: _i4.Future<List<Object?>>.value(<Object?>[]),
      ) as _i4.Future<List<Object?>>);

  @override
  _i4.Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) =>
      (super.noSuchMethod(
        Invocation.method(#apply, [], {
          #noResult: noResult,
          #continueOnError: continueOnError,
        }),
        returnValue: _i4.Future<List<Object?>>.value(<Object?>[]),
      ) as _i4.Future<List<Object?>>);

  @override
  void rawInsert(String? sql, [List<Object?>? arguments]) => super.noSuchMethod(
        Invocation.method(#rawInsert, [sql, arguments]),
        returnValueForMissingStub: null,
      );

  @override
  void insert(
    String? table,
    Map<String, Object?>? values, {
    String? nullColumnHack,
    _i8.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #insert,
          [table, values],
          {
            #nullColumnHack: nullColumnHack,
            #conflictAlgorithm: conflictAlgorithm
          },
        ),
        returnValueForMissingStub: null,
      );

  @override
  void rawUpdate(String? sql, [List<Object?>? arguments]) => super.noSuchMethod(
        Invocation.method(#rawUpdate, [sql, arguments]),
        returnValueForMissingStub: null,
      );

  @override
  void update(
    String? table,
    Map<String, Object?>? values, {
    String? where,
    List<Object?>? whereArgs,
    _i8.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #update,
          [table, values],
          {
            #where: where,
            #whereArgs: whereArgs,
            #conflictAlgorithm: conflictAlgorithm,
          },
        ),
        returnValueForMissingStub: null,
      );

  @override
  void rawDelete(String? sql, [List<Object?>? arguments]) => super.noSuchMethod(
        Invocation.method(#rawDelete, [sql, arguments]),
        returnValueForMissingStub: null,
      );

  @override
  void delete(String? table, {String? where, List<Object?>? whereArgs}) =>
      super.noSuchMethod(
        Invocation.method(
          #delete,
          [table],
          {#where: where, #whereArgs: whereArgs},
        ),
        returnValueForMissingStub: null,
      );

  @override
  void execute(String? sql, [List<Object?>? arguments]) => super.noSuchMethod(
        Invocation.method(#execute, [sql, arguments]),
        returnValueForMissingStub: null,
      );

  @override
  void query(
    String? table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #query,
          [table],
          {
            #distinct: distinct,
            #columns: columns,
            #where: where,
            #whereArgs: whereArgs,
            #groupBy: groupBy,
            #having: having,
            #orderBy: orderBy,
            #limit: limit,
            #offset: offset,
          },
        ),
        returnValueForMissingStub: null,
      );

  @override
  void rawQuery(String? sql, [List<Object?>? arguments]) => super.noSuchMethod(
        Invocation.method(#rawQuery, [sql, arguments]),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [Database].
///
/// See the documentation for Mockito's code generation for more information.
class MockDatabase extends _i1.Mock implements _i3.Database {
  MockDatabase() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get path => (super.noSuchMethod(
        Invocation.getter(#path),
        returnValue: _i6.dummyValue<String>(this, Invocation.getter(#path)),
      ) as String);

  @override
  bool get isOpen =>
      (super.noSuchMethod(Invocation.getter(#isOpen), returnValue: false)
          as bool);

  @override
  _i3.Database get database => (super.noSuchMethod(
        Invocation.getter(#database),
        returnValue: _FakeDatabase_4(this, Invocation.getter(#database)),
      ) as _i3.Database);

  @override
  _i4.Future<void> close() => (super.noSuchMethod(
        Invocation.method(#close, []),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<T> transaction<T>(
    _i4.Future<T> Function(_i3.Transaction)? action, {
    bool? exclusive,
  }) =>
      (super.noSuchMethod(
        Invocation.method(#transaction, [action], {#exclusive: exclusive}),
        returnValue: _i6.ifNotNull(
              _i6.dummyValueOrNull<T>(
                this,
                Invocation.method(
                  #transaction,
                  [action],
                  {#exclusive: exclusive},
                ),
              ),
              (T v) => _i4.Future<T>.value(v),
            ) ??
            _FakeFuture_5<T>(
              this,
              Invocation.method(
                #transaction,
                [action],
                {#exclusive: exclusive},
              ),
            ),
      ) as _i4.Future<T>);

  @override
  _i4.Future<T> readTransaction<T>(
    _i4.Future<T> Function(_i3.Transaction)? action,
  ) =>
      (super.noSuchMethod(
        Invocation.method(#readTransaction, [action]),
        returnValue: _i6.ifNotNull(
              _i6.dummyValueOrNull<T>(
                this,
                Invocation.method(#readTransaction, [action]),
              ),
              (T v) => _i4.Future<T>.value(v),
            ) ??
            _FakeFuture_5<T>(
              this,
              Invocation.method(#readTransaction, [action]),
            ),
      ) as _i4.Future<T>);

  @override
  _i4.Future<T> devInvokeMethod<T>(String? method, [Object? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#devInvokeMethod, [method, arguments]),
        returnValue: _i6.ifNotNull(
              _i6.dummyValueOrNull<T>(
                this,
                Invocation.method(#devInvokeMethod, [method, arguments]),
              ),
              (T v) => _i4.Future<T>.value(v),
            ) ??
            _FakeFuture_5<T>(
              this,
              Invocation.method(#devInvokeMethod, [method, arguments]),
            ),
      ) as _i4.Future<T>);

  @override
  _i4.Future<T> devInvokeSqlMethod<T>(
    String? method,
    String? sql, [
    List<Object?>? arguments,
  ]) =>
      (super.noSuchMethod(
        Invocation.method(#devInvokeSqlMethod, [method, sql, arguments]),
        returnValue: _i6.ifNotNull(
              _i6.dummyValueOrNull<T>(
                this,
                Invocation.method(#devInvokeSqlMethod, [
                  method,
                  sql,
                  arguments,
                ]),
              ),
              (T v) => _i4.Future<T>.value(v),
            ) ??
            _FakeFuture_5<T>(
              this,
              Invocation.method(#devInvokeSqlMethod, [
                method,
                sql,
                arguments,
              ]),
            ),
      ) as _i4.Future<T>);

  @override
  _i4.Future<void> execute(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#execute, [sql, arguments]),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<int> rawInsert(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#rawInsert, [sql, arguments]),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> insert(
    String? table,
    Map<String, Object?>? values, {
    String? nullColumnHack,
    _i8.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #insert,
          [table, values],
          {
            #nullColumnHack: nullColumnHack,
            #conflictAlgorithm: conflictAlgorithm,
          },
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<List<Map<String, Object?>>> query(
    String? table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #query,
          [table],
          {
            #distinct: distinct,
            #columns: columns,
            #where: where,
            #whereArgs: whereArgs,
            #groupBy: groupBy,
            #having: having,
            #orderBy: orderBy,
            #limit: limit,
            #offset: offset,
          },
        ),
        returnValue: _i4.Future<List<Map<String, Object?>>>.value(
          <Map<String, Object?>>[],
        ),
      ) as _i4.Future<List<Map<String, Object?>>>);

  @override
  _i4.Future<List<Map<String, Object?>>> rawQuery(
    String? sql, [
    List<Object?>? arguments,
  ]) =>
      (super.noSuchMethod(
        Invocation.method(#rawQuery, [sql, arguments]),
        returnValue: _i4.Future<List<Map<String, Object?>>>.value(
          <Map<String, Object?>>[],
        ),
      ) as _i4.Future<List<Map<String, Object?>>>);

  @override
  _i4.Future<_i3.QueryCursor> rawQueryCursor(
    String? sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #rawQueryCursor,
          [sql, arguments],
          {#bufferSize: bufferSize},
        ),
        returnValue: _i4.Future<_i3.QueryCursor>.value(
          _FakeQueryCursor_6(
            this,
            Invocation.method(
              #rawQueryCursor,
              [sql, arguments],
              {#bufferSize: bufferSize},
            ),
          ),
        ),
      ) as _i4.Future<_i3.QueryCursor>);

  @override
  _i4.Future<_i3.QueryCursor> queryCursor(
    String? table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #queryCursor,
          [table],
          {
            #distinct: distinct,
            #columns: columns,
            #where: where,
            #whereArgs: whereArgs,
            #groupBy: groupBy,
            #having: having,
            #orderBy: orderBy,
            #limit: limit,
            #offset: offset,
            #bufferSize: bufferSize,
          },
        ),
        returnValue: _i4.Future<_i3.QueryCursor>.value(
          _FakeQueryCursor_6(
            this,
            Invocation.method(
              #queryCursor,
              [table],
              {
                #distinct: distinct,
                #columns: columns,
                #where: where,
                #whereArgs: whereArgs,
                #groupBy: groupBy,
                #having: having,
                #orderBy: orderBy,
                #limit: limit,
                #offset: offset,
                #bufferSize: bufferSize,
              },
            ),
          ),
        ),
      ) as _i4.Future<_i3.QueryCursor>);

  @override
  _i4.Future<int> rawUpdate(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#rawUpdate, [sql, arguments]),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> update(
    String? table,
    Map<String, Object?>? values, {
    String? where,
    List<Object?>? whereArgs,
    _i8.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #update,
          [table, values],
          {
            #where: where,
            #whereArgs: whereArgs,
            #conflictAlgorithm: conflictAlgorithm,
          },
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> rawDelete(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#rawDelete, [sql, arguments]),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> delete(
    String? table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #delete,
          [table],
          {#where: where, #whereArgs: whereArgs},
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i3.Batch batch() => (super.noSuchMethod(
        Invocation.method(#batch, []),
        returnValue: _FakeBatch_7(this, Invocation.method(#batch, [])),
      ) as _i3.Batch);
}

/// A class which mocks [DatabaseExecutor].
///
/// See the documentation for Mockito's code generation for more information.
class MockDatabaseExecutor extends _i1.Mock implements _i3.DatabaseExecutor {
  MockDatabaseExecutor() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Database get database => (super.noSuchMethod(
        Invocation.getter(#database),
        returnValue: _FakeDatabase_4(this, Invocation.getter(#database)),
      ) as _i3.Database);

  @override
  _i4.Future<void> execute(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#execute, [sql, arguments]),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<int> rawInsert(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#rawInsert, [sql, arguments]),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> insert(
    String? table,
    Map<String, Object?>? values, {
    String? nullColumnHack,
    _i8.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #insert,
          [table, values],
          {
            #nullColumnHack: nullColumnHack,
            #conflictAlgorithm: conflictAlgorithm,
          },
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<List<Map<String, Object?>>> query(
    String? table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #query,
          [table],
          {
            #distinct: distinct,
            #columns: columns,
            #where: where,
            #whereArgs: whereArgs,
            #groupBy: groupBy,
            #having: having,
            #orderBy: orderBy,
            #limit: limit,
            #offset: offset,
          },
        ),
        returnValue: _i4.Future<List<Map<String, Object?>>>.value(
          <Map<String, Object?>>[],
        ),
      ) as _i4.Future<List<Map<String, Object?>>>);

  @override
  _i4.Future<List<Map<String, Object?>>> rawQuery(
    String? sql, [
    List<Object?>? arguments,
  ]) =>
      (super.noSuchMethod(
        Invocation.method(#rawQuery, [sql, arguments]),
        returnValue: _i4.Future<List<Map<String, Object?>>>.value(
          <Map<String, Object?>>[],
        ),
      ) as _i4.Future<List<Map<String, Object?>>>);

  @override
  _i4.Future<_i3.QueryCursor> rawQueryCursor(
    String? sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #rawQueryCursor,
          [sql, arguments],
          {#bufferSize: bufferSize},
        ),
        returnValue: _i4.Future<_i3.QueryCursor>.value(
          _FakeQueryCursor_6(
            this,
            Invocation.method(
              #rawQueryCursor,
              [sql, arguments],
              {#bufferSize: bufferSize},
            ),
          ),
        ),
      ) as _i4.Future<_i3.QueryCursor>);

  @override
  _i4.Future<_i3.QueryCursor> queryCursor(
    String? table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #queryCursor,
          [table],
          {
            #distinct: distinct,
            #columns: columns,
            #where: where,
            #whereArgs: whereArgs,
            #groupBy: groupBy,
            #having: having,
            #orderBy: orderBy,
            #limit: limit,
            #offset: offset,
            #bufferSize: bufferSize,
          },
        ),
        returnValue: _i4.Future<_i3.QueryCursor>.value(
          _FakeQueryCursor_6(
            this,
            Invocation.method(
              #queryCursor,
              [table],
              {
                #distinct: distinct,
                #columns: columns,
                #where: where,
                #whereArgs: whereArgs,
                #groupBy: groupBy,
                #having: having,
                #orderBy: orderBy,
                #limit: limit,
                #offset: offset,
                #bufferSize: bufferSize,
              },
            ),
          ),
        ),
      ) as _i4.Future<_i3.QueryCursor>);

  @override
  _i4.Future<int> rawUpdate(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#rawUpdate, [sql, arguments]),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> update(
    String? table,
    Map<String, Object?>? values, {
    String? where,
    List<Object?>? whereArgs,
    _i8.ConflictAlgorithm? conflictAlgorithm,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #update,
          [table, values],
          {
            #where: where,
            #whereArgs: whereArgs,
            #conflictAlgorithm: conflictAlgorithm,
          },
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> rawDelete(String? sql, [List<Object?>? arguments]) =>
      (super.noSuchMethod(
        Invocation.method(#rawDelete, [sql, arguments]),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> delete(
    String? table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #delete,
          [table],
          {#where: where, #whereArgs: whereArgs},
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i3.Batch batch() => (super.noSuchMethod(
        Invocation.method(#batch, []),
        returnValue: _FakeBatch_7(this, Invocation.method(#batch, [])),
      ) as _i3.Batch);
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
        returnValue: _FakeSentryOptions_8(
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
        returnValue: _FakeSentryId_9(this, Invocation.getter(#lastEventId)),
      ) as _i2.SentryId);

  @override
  _i2.Scope get scope => (super.noSuchMethod(
        Invocation.getter(#scope),
        returnValue: _FakeScope_10(this, Invocation.getter(#scope)),
      ) as _i2.Scope);

  @override
  // ignore: invalid_use_of_internal_member
  set profilerFactory(_i7.SentryProfilerFactory? value) => super.noSuchMethod(
        Invocation.setter(#profilerFactory, value),
        returnValueForMissingStub: null,
      );

  @override
  _i4.Future<_i2.SentryId> captureEvent(
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
        returnValue: _i4.Future<_i2.SentryId>.value(
          _FakeSentryId_9(
            this,
            Invocation.method(
              #captureEvent,
              [event],
              {#stackTrace: stackTrace, #hint: hint, #withScope: withScope},
            ),
          ),
        ),
      ) as _i4.Future<_i2.SentryId>);

  @override
  _i4.Future<_i2.SentryId> captureException(
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
        returnValue: _i4.Future<_i2.SentryId>.value(
          _FakeSentryId_9(
            this,
            Invocation.method(
              #captureException,
              [throwable],
              {#stackTrace: stackTrace, #hint: hint, #withScope: withScope},
            ),
          ),
        ),
      ) as _i4.Future<_i2.SentryId>);

  @override
  _i4.Future<_i2.SentryId> captureMessage(
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
        returnValue: _i4.Future<_i2.SentryId>.value(
          _FakeSentryId_9(
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
      ) as _i4.Future<_i2.SentryId>);

  @override
  _i4.Future<void> captureUserFeedback(_i2.SentryUserFeedback? userFeedback) =>
      (super.noSuchMethod(
        Invocation.method(#captureUserFeedback, [userFeedback]),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<_i2.SentryId> captureFeedback(
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
        returnValue: _i4.Future<_i2.SentryId>.value(
          _FakeSentryId_9(
            this,
            Invocation.method(
              #captureFeedback,
              [feedback],
              {#hint: hint, #withScope: withScope},
            ),
          ),
        ),
      ) as _i4.Future<_i2.SentryId>);

  @override
  _i4.Future<void> addBreadcrumb(_i2.Breadcrumb? crumb, {_i2.Hint? hint}) =>
      (super.noSuchMethod(
        Invocation.method(#addBreadcrumb, [crumb], {#hint: hint}),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  void bindClient(_i2.SentryClient? client) => super.noSuchMethod(
        Invocation.method(#bindClient, [client]),
        returnValueForMissingStub: null,
      );

  @override
  _i2.Hub clone() => (super.noSuchMethod(
        Invocation.method(#clone, []),
        returnValue: _FakeHub_11(this, Invocation.method(#clone, [])),
      ) as _i2.Hub);

  @override
  _i4.Future<void> close() => (super.noSuchMethod(
        Invocation.method(#close, []),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.FutureOr<void> configureScope(_i2.ScopeCallback? callback) =>
      (super.noSuchMethod(Invocation.method(#configureScope, [callback]))
          as _i4.FutureOr<void>);

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
        returnValue: _i9.startTransactionShim(
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
  _i4.Future<_i2.SentryId> captureTransaction(
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
        returnValue: _i4.Future<_i2.SentryId>.value(
          _FakeSentryId_9(
            this,
            Invocation.method(
              #captureTransaction,
              [transaction],
              {#traceContext: traceContext, #hint: hint},
            ),
          ),
        ),
      ) as _i4.Future<_i2.SentryId>);

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
