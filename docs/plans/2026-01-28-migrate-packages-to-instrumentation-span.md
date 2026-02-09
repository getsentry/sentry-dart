# Migration to InstrumentationSpan/SpanFactory Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate packages hive, isar, file, supabase, and link from legacy span API (`hub.getSpan()?.startChild()`) to the new `InstrumentationSpanFactory`/`InstrumentationSpan` pattern (as implemented in drift and sqflite).

**Architecture:** Each package's span creation will be refactored to use `hub.options.spanFactory` to create spans via the factory pattern. This enables swappable tracing backends and consistent null-safety handling. Packages with sync operations (hive, isar, file) will use fire-and-forget `span.finish()` calls.

**Tech Stack:** Dart, Sentry SDK internal APIs (`InstrumentationSpanFactory`, `InstrumentationSpan`, `SentryInternalLogger`)

---

## Prerequisites

### Task 0: Create Feature Branch

**Files:**
- N/A (git operation)

**Step 1: Create and checkout new branch**

```bash
git checkout -b feat/migrate-packages-instrumentation-span
```

**Step 2: Verify branch created**

Run: `git branch --show-current`
Expected: `feat/migrate-packages-instrumentation-span`

---

## Package 1: Hive Migration

### Task 1.1: Add Internal Logger to Hive Package

**Files:**
- Create: `packages/hive/lib/src/internal_logger.dart`

**Step 1: Create the internal logger file**

```dart
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Internal logger for sentry_hive package.
@internal
const internalLogger = SentryInternalLogger('sentry_hive');
```

**Step 2: Verify file created**

Run: `cat packages/hive/lib/src/internal_logger.dart`
Expected: File contents match above

**Step 3: Commit**

```bash
git add packages/hive/lib/src/internal_logger.dart
git commit -m "$(cat <<'EOF'
feat(hive): add internal logger for sentry_hive package

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.2: Migrate Hive SentrySpanHelper to InstrumentationSpan

**Files:**
- Modify: `packages/hive/lib/src/sentry_span_helper.dart`

**Step 1: Read current implementation to understand exact structure**

Read the file at `packages/hive/lib/src/sentry_span_helper.dart`.

**Step 2: Replace entire file with new implementation**

```dart
// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'internal_logger.dart';
import 'sentry_hive_impl.dart';

/// @nodoc
@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  late final InstrumentationSpanFactory _factory;

  /// @nodoc
  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _factory = _hub.options.spanFactory;
  }

  /// @nodoc
  @internal
  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
  }) async {
    final parentSpan = _factory.getSpan(_hub);
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Hive operation: $description',
      );
      return execute();
    }

    final span = _factory.createSpan(
      parentSpan,
      SentryHiveImpl.dbOp,
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    span.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);
    if (dbName != null) {
      span.setData(SentryHiveImpl.dbNameKey, dbName);
    }

    final breadcrumb = Breadcrumb(
      message: description,
      data: {
        SentryHiveImpl.dbSystemKey: SentryHiveImpl.dbSystem,
        if (dbName != null) SentryHiveImpl.dbNameKey: dbName,
      },
      type: 'query',
    );

    try {
      final result = await execute();
      span.status = SpanStatus.ok();
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      await span.finish();
      await _hub.scope.addBreadcrumb(breadcrumb);
    }
  }

  /// @nodoc
  @internal
  T syncWrapInSpan<T>(
    String description,
    T Function() execute, {
    String? dbName,
  }) {
    final parentSpan = _factory.getSpan(_hub);
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Hive operation: $description',
      );
      return execute();
    }

    final span = _factory.createSpan(
      parentSpan,
      SentryHiveImpl.dbOp,
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    span.setData('sync', true);
    span.setData(SentryHiveImpl.dbSystemKey, SentryHiveImpl.dbSystem);
    if (dbName != null) {
      span.setData(SentryHiveImpl.dbNameKey, dbName);
    }

    final breadcrumb = Breadcrumb(
      message: description,
      data: {
        SentryHiveImpl.dbSystemKey: SentryHiveImpl.dbSystem,
        if (dbName != null) SentryHiveImpl.dbNameKey: dbName,
      },
      type: 'query',
    );

    try {
      final result = execute();
      span.status = SpanStatus.ok();
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      // Fire-and-forget for sync operations
      span.finish();
      _hub.scope.addBreadcrumb(breadcrumb);
    }
  }
}
```

**Step 3: Run tests to verify no regressions**

Run: `cd packages/hive && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/hive/lib/src/sentry_span_helper.dart
git commit -m "$(cat <<'EOF'
feat(hive): migrate SentrySpanHelper to InstrumentationSpan

- Use InstrumentationSpanFactory instead of hub.getSpan()?.startChild()
- Add proper null checks with warning logs
- Maintain both async and sync wrapper methods

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.3: Update Hive Classes to Use New Constructor Pattern

**Files:**
- Modify: `packages/hive/lib/src/sentry_box_base.dart`
- Modify: `packages/hive/lib/src/sentry_box.dart`
- Modify: `packages/hive/lib/src/sentry_lazy_box.dart`
- Modify: `packages/hive/lib/src/sentry_box_collection.dart`
- Modify: `packages/hive/lib/src/sentry_hive_impl.dart`

**Step 1: Update sentry_box_base.dart**

Change the SentrySpanHelper initialization to pass Hub in constructor:

Replace:
```dart
  final _spanHelper = SentrySpanHelper(
    // ignore: invalid_use_of_internal_member
    SentryTraceOrigins.autoDbHiveBoxBase,
  );

  /// @nodoc
  SentryBoxBase(this._boxBase, this._hub) {
    _spanHelper.setHub(_hub);
  }
```

With:
```dart
  late final SentrySpanHelper _spanHelper;

  /// @nodoc
  SentryBoxBase(this._boxBase, this._hub) {
    _spanHelper = SentrySpanHelper(
      // ignore: invalid_use_of_internal_member
      SentryTraceOrigins.autoDbHiveBoxBase,
      hub: _hub,
    );
  }
```

**Step 2: Update sentry_box.dart similarly**

Replace the _spanHelper initialization pattern to use constructor with hub parameter.

**Step 3: Update sentry_lazy_box.dart similarly**

Replace the _spanHelper initialization pattern.

**Step 4: Update sentry_box_collection.dart similarly**

Replace the _spanHelper initialization pattern.

**Step 5: Update sentry_hive_impl.dart similarly**

Replace the _spanHelper initialization pattern.

**Step 6: Run tests**

Run: `cd packages/hive && dart test`
Expected: All tests pass

**Step 7: Commit**

```bash
git add packages/hive/lib/src/
git commit -m "$(cat <<'EOF'
feat(hive): update classes to use new SentrySpanHelper constructor

- Pass Hub directly to SentrySpanHelper constructor
- Remove setHub() method calls

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 1.4: Run Full Hive Test Suite

**Files:**
- Test: `packages/hive/test/`

**Step 1: Run all hive tests**

Run: `cd packages/hive && dart test`
Expected: All tests pass

**Step 2: Run analyze**

Run: `cd packages/hive && dart analyze`
Expected: No issues found

---

## Package 2: Isar Migration

### Task 2.1: Add Internal Logger to Isar Package

**Files:**
- Create: `packages/isar/lib/src/internal_logger.dart`

**Step 1: Create the internal logger file**

```dart
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Internal logger for sentry_isar package.
@internal
const internalLogger = SentryInternalLogger('sentry_isar');
```

**Step 2: Commit**

```bash
git add packages/isar/lib/src/internal_logger.dart
git commit -m "$(cat <<'EOF'
feat(isar): add internal logger for sentry_isar package

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.2: Migrate Isar SentrySpanHelper to InstrumentationSpan

**Files:**
- Modify: `packages/isar/lib/src/sentry_span_helper.dart`

**Step 1: Read current implementation**

Read the file at `packages/isar/lib/src/sentry_span_helper.dart`.

**Step 2: Replace entire file with new implementation**

```dart
// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'internal_logger.dart';
import 'sentry_isar.dart';

/// @nodoc
@internal
class SentrySpanHelper {
  final Hub _hub;
  final String _origin;
  late final InstrumentationSpanFactory _factory;

  /// @nodoc
  SentrySpanHelper(this._origin, {Hub? hub}) : _hub = hub ?? HubAdapter() {
    _factory = _hub.options.spanFactory;
  }

  /// @nodoc
  @internal
  Future<T> asyncWrapInSpan<T>(
    String description,
    Future<T> Function() execute, {
    String? dbName,
    String? collectionName,
  }) async {
    final parentSpan = _factory.getSpan(_hub);
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Isar operation: $description',
      );
      return execute();
    }

    final span = _factory.createSpan(
      parentSpan,
      SentryIsar.dbOp,
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    span.setData(SentryIsar.dbSystemKey, SentryIsar.dbSystem);
    if (dbName != null) {
      span.setData(SentryIsar.dbNameKey, dbName);
    }
    if (collectionName != null) {
      span.setData(SentryIsar.dbCollectionKey, collectionName);
    }

    final breadcrumb = Breadcrumb(
      message: description,
      data: {
        if (dbName != null) SentryIsar.dbNameKey: dbName,
        if (collectionName != null) SentryIsar.dbCollectionKey: collectionName,
      },
      type: 'query',
    );

    try {
      final result = await execute();
      span.status = SpanStatus.ok();
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      await span.finish();
      await _hub.scope.addBreadcrumb(breadcrumb);
    }
  }

  /// @nodoc
  @internal
  T syncWrapInSpan<T>(
    String description,
    T Function() execute, {
    String? dbName,
    String? collectionName,
  }) {
    final parentSpan = _factory.getSpan(_hub);
    if (parentSpan == null) {
      internalLogger.warning(
        'No active span found. Skipping tracing for Isar operation: $description',
      );
      return execute();
    }

    final span = _factory.createSpan(
      parentSpan,
      SentryIsar.dbOp,
      description: description,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    span.setData('sync', true);
    span.setData(SentryIsar.dbSystemKey, SentryIsar.dbSystem);
    if (dbName != null) {
      span.setData(SentryIsar.dbNameKey, dbName);
    }
    if (collectionName != null) {
      span.setData(SentryIsar.dbCollectionKey, collectionName);
    }

    final breadcrumb = Breadcrumb(
      message: description,
      data: {
        if (dbName != null) SentryIsar.dbNameKey: dbName,
        if (collectionName != null) SentryIsar.dbCollectionKey: collectionName,
      },
      type: 'query',
    );

    try {
      final result = execute();
      span.status = SpanStatus.ok();
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      // Fire-and-forget for sync operations
      span.finish();
      _hub.scope.addBreadcrumb(breadcrumb);
    }
  }
}
```

**Step 3: Run tests**

Run: `cd packages/isar && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/isar/lib/src/sentry_span_helper.dart
git commit -m "$(cat <<'EOF'
feat(isar): migrate SentrySpanHelper to InstrumentationSpan

- Use InstrumentationSpanFactory instead of hub.getSpan()?.startChild()
- Add proper null checks with warning logs
- Maintain both async and sync wrapper methods

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.3: Update Isar Classes to Use New Constructor Pattern

**Files:**
- Modify: `packages/isar/lib/src/sentry_isar.dart`
- Modify: `packages/isar/lib/src/sentry_isar_collection.dart`

**Step 1: Update sentry_isar.dart**

Change the SentrySpanHelper initialization to pass Hub in constructor (same pattern as Hive).

**Step 2: Update sentry_isar_collection.dart**

Change the SentrySpanHelper initialization.

**Step 3: Run tests**

Run: `cd packages/isar && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/isar/lib/src/
git commit -m "$(cat <<'EOF'
feat(isar): update classes to use new SentrySpanHelper constructor

- Pass Hub directly to SentrySpanHelper constructor
- Remove setHub() method calls

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2.4: Run Full Isar Test Suite

**Files:**
- Test: `packages/isar/test/`

**Step 1: Run all isar tests**

Run: `cd packages/isar && dart test`
Expected: All tests pass

**Step 2: Run analyze**

Run: `cd packages/isar && dart analyze`
Expected: No issues found

---

## Package 3: File Migration

### Task 3.1: Migrate File Package to InstrumentationSpan

**Files:**
- Modify: `packages/file/lib/src/sentry_file.dart`

**Step 1: Read current implementation**

Read the file at `packages/file/lib/src/sentry_file.dart`.

**Step 2: Update imports and add factory field**

Add at the top after existing imports:
```dart
// ignore_for_file: invalid_use_of_internal_member
```

Add field to the class:
```dart
late final InstrumentationSpanFactory _spanFactory;
```

Update constructor to initialize factory:
```dart
SentryFile(
  this._file, {
  @internal Hub? hub,
}) : _hub = hub ?? HubAdapter() {
  _spanFactory = _hub.options.spanFactory;
  _hub.options.sdk.addIntegration('SentryFileTracing');
  _hub.options.sdk.addPackage(packageName, sdkVersion);
}
```

**Step 3: Update _wrap method**

Replace the `_wrap` method:
```dart
Future<T> _wrap<T>(Callback<T> callback, String operation) async {
  final desc = _getDesc();

  final parentSpan = _spanFactory.getSpan(_hub);
  final span = _spanFactory.createSpan(
    parentSpan,
    operation,
    description: desc,
  );

  span?.origin = SentryTraceOrigins.autoFile;
  span?.setData('file.async', true);

  final Map<String, dynamic> breadcrumbData = {};
  breadcrumbData['file.async'] = true;

  if (_hub.options.sendDefaultPii) {
    span?.setData('file.path', absolute.path);
    breadcrumbData['file.path'] = absolute.path;
  }
  T data;
  try {
    // workaround for having the length when the file does not exist
    // or its being deleted.
    int? length;
    var hasLength = false;
    try {
      length = await _file.length();
      hasLength = true;
    } catch (_) {
      // ignore in case something goes wrong
    }

    data = await callback();

    if (!hasLength) {
      try {
        length = await _file.length();
      } catch (_) {
        // ignore in case something goes wrong
      }
    }

    if (length != null) {
      span?.setData('file.size', length);
      breadcrumbData['file.size'] = length;
    }

    span?.status = SpanStatus.ok();
  } catch (exception) {
    span?.throwable = exception;
    span?.status = SpanStatus.internalError();
    rethrow;
  } finally {
    await span?.finish();

    await _hub.addBreadcrumb(
      Breadcrumb(
        message: desc,
        data: breadcrumbData,
        category: operation,
      ),
    );
  }
  return data;
}
```

**Step 4: Update _wrapSync method**

Replace the `_wrapSync` method:
```dart
T _wrapSync<T>(Callback<T> callback, String operation) {
  final desc = _getDesc();

  final parentSpan = _spanFactory.getSpan(_hub);
  final span = _spanFactory.createSpan(
    parentSpan,
    operation,
    description: desc,
  );

  span?.origin = SentryTraceOrigins.autoFile;
  span?.setData('file.async', false);
  span?.setData('sync', true);

  final Map<String, dynamic> breadcrumbData = {};
  breadcrumbData['file.async'] = false;

  if (_hub.options.sendDefaultPii) {
    span?.setData('file.path', absolute.path);
    breadcrumbData['file.path'] = absolute.path;
  }

  T data;
  try {
    // workaround for having the length when the file does not exist
    // or its being deleted.
    int? length;
    var hasLength = false;
    try {
      length = _file.lengthSync();
      hasLength = true;
    } catch (_) {
      // ignore in case something goes wrong
    }

    data = callback() as T;

    if (!hasLength) {
      try {
        length = _file.lengthSync();
      } catch (_) {
        // ignore in case something goes wrong
      }
    }

    if (length != null) {
      span?.setData('file.size', length);
      breadcrumbData['file.size'] = length;
    }

    span?.status = SpanStatus.ok();
  } catch (exception) {
    span?.throwable = exception;
    span?.status = SpanStatus.internalError();
    rethrow;
  } finally {
    // Fire-and-forget for sync operations
    span?.finish();

    _hub.addBreadcrumb(
      Breadcrumb(
        message: desc,
        data: breadcrumbData,
        category: operation,
      ),
    );
  }
  return data;
}
```

**Step 5: Run tests**

Run: `cd packages/file && dart test`
Expected: All tests pass

**Step 6: Commit**

```bash
git add packages/file/lib/src/sentry_file.dart
git commit -m "$(cat <<'EOF'
feat(file): migrate to InstrumentationSpan

- Use InstrumentationSpanFactory instead of hub.getSpan()?.startChild()
- Maintain both async and sync wrapper methods

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3.2: Run Full File Test Suite

**Files:**
- Test: `packages/file/test/`

**Step 1: Run all file tests**

Run: `cd packages/file && dart test`
Expected: All tests pass

**Step 2: Run analyze**

Run: `cd packages/file && dart analyze`
Expected: No issues found

---

## Package 4: Supabase Migration

### Task 4.1: Migrate Supabase Tracing Client to InstrumentationSpan

**Files:**
- Modify: `packages/supabase/lib/src/sentry_supabase_tracing_client.dart`

**Step 1: Read current implementation**

Read the file at `packages/supabase/lib/src/sentry_supabase_tracing_client.dart`.

**Step 2: Update the file to use InstrumentationSpan**

```dart
// ignore_for_file: invalid_use_of_internal_member

import 'package:http/http.dart';
import 'package:sentry/sentry.dart';

import 'constants.dart';
import 'sentry_supabase_request.dart';

class SentrySupabaseTracingClient extends BaseClient {
  final Client _innerClient;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  SentrySupabaseTracingClient(this._innerClient, this._hub) {
    _spanFactory = _hub.options.spanFactory;
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final supabaseRequest = SentrySupabaseRequest.fromRequest(
      request,
      options: _hub.options,
    );
    if (supabaseRequest == null) {
      return _innerClient.send(request);
    }

    final span = _createSpan(supabaseRequest);

    StreamedResponse? response;

    try {
      response = await _innerClient.send(request);

      span?.setData(
        SentrySpanData.httpResponseStatusCodeKey,
        response.statusCode,
      );
      span?.setData(
        SentrySpanData.httpResponseContentLengthKey,
        response.contentLength,
      );
      span?.status = SpanStatus.fromHttpStatusCode(response.statusCode);
    } catch (e) {
      span?.throwable = e;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }

    return response;
  }

  @override
  void close() {
    _innerClient.close();
  }

  // Helper

  InstrumentationSpan? _createSpan(SentrySupabaseRequest supabaseRequest) {
    final parentSpan = _spanFactory.getSpan(_hub);
    if (parentSpan == null) {
      _hub.options.log(
        SentryLevel.warning,
        'Active Sentry transaction does not exist, could not start span for the Supabase operation: from(${supabaseRequest.table})',
        logger: loggerName,
      );
      return null;
    }

    final span = _spanFactory.createSpan(
      parentSpan,
      'db.${supabaseRequest.operation.value}',
      description: 'from(${supabaseRequest.table})',
    );

    if (span == null) {
      return null;
    }

    final dbSchema = supabaseRequest.request.headers['Accept-Profile'] ??
        supabaseRequest.request.headers['Content-Profile'];
    if (dbSchema != null) {
      span.setData(SentrySpanData.dbSchemaKey, dbSchema);
    }
    span.setData(SentrySpanData.dbTableKey, supabaseRequest.table);
    span.setData(SentrySpanData.dbUrlKey, supabaseRequest.request.url.origin);
    final dbSdk = supabaseRequest.request.headers['X-Client-Info'];
    if (dbSdk != null) {
      span.setData(SentrySpanData.dbSdkKey, dbSdk);
    }
    if (supabaseRequest.query.isNotEmpty && _hub.options.sendDefaultPii) {
      span.setData(SentrySpanData.dbQueryKey, supabaseRequest.query);
    }
    if (supabaseRequest.body != null && _hub.options.sendDefaultPii) {
      span.setData(SentrySpanData.dbBodyKey, supabaseRequest.body);
    }
    span.setData(
      SentrySpanData.dbOperationKey,
      supabaseRequest.operation.value,
    );
    span.setData(
      SentrySpanOperations.dbSqlQuery,
      supabaseRequest.generateSqlQuery(),
    );
    span.setData(SentrySpanData.dbSystemKey, SentrySpanData.dbSystemPostgresql);
    span.origin = SentryTraceOrigins.autoDbSupabase;
    return span;
  }
}
```

**Step 3: Run tests**

Run: `cd packages/supabase && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/supabase/lib/src/sentry_supabase_tracing_client.dart
git commit -m "$(cat <<'EOF'
feat(supabase): migrate to InstrumentationSpan

- Use InstrumentationSpanFactory instead of hub.getSpan()?.startChild()
- Return InstrumentationSpan from _createSpan helper

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4.2: Run Full Supabase Test Suite

**Files:**
- Test: `packages/supabase/test/`

**Step 1: Run all supabase tests**

Run: `cd packages/supabase && dart test`
Expected: All tests pass

**Step 2: Run analyze**

Run: `cd packages/supabase && dart analyze`
Expected: No issues found

---

## Package 5: Link (GraphQL) Migration

### Task 5.1: Migrate SentryTracingLink to InstrumentationSpan

**Files:**
- Modify: `packages/link/lib/src/sentry_tracing_link.dart`

**Step 1: Read current implementation**

Read the file at `packages/link/lib/src/sentry_tracing_link.dart`.

**Step 2: Update the file to use InstrumentationSpan**

Note: The link package has a special case where it may start a transaction if `shouldStartTransaction` is true. We need to handle this case carefully. The `InstrumentationSpanFactory` only creates child spans, not transactions. For transaction creation, we keep using `hub.startTransaction()`.

```dart
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_link/src/extension.dart';

class SentryTracingLink extends Link {
  /// If [shouldStartTransaction] is set to true, a [SentryTransaction]
  /// is automatically created for each GraphQL query/mutation.
  /// If a transaction is already bound to scope, no [SentryTransaction]
  /// will be started even if [shouldStartTransaction] is set to true.
  ///
  /// If [graphQlErrorsMarkTransactionAsFailed] is set to true and a
  /// query or mutation have a [GraphQLError] attached, the current
  /// [SentryTransaction] is marked as with [SpanStatus.unknownError].
  SentryTracingLink({
    required this.shouldStartTransaction,
    required this.graphQlErrorsMarkTransactionAsFailed,
    Hub? hub,
  }) : _hub = hub ?? HubAdapter() {
    _spanFactory = _hub.options.spanFactory;
  }

  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  /// If [shouldStartTransaction] is set to true, a [SentryTransaction]
  /// is automatically created for each GraphQL query/mutation.
  /// If a transaction is already bound to scope, no [SentryTransaction]
  /// will be started even if [shouldStartTransaction] is set to true.
  final bool shouldStartTransaction;

  /// If [graphQlErrorsMarkTransactionAsFailed] is set to true and a
  /// query or mutation have a [GraphQLError] attached, the current
  /// [SentryTransaction] is marked as with [SpanStatus.unknownError].
  final bool graphQlErrorsMarkTransactionAsFailed;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    assert(
      forward != null,
      'This is not a terminating link and needs a NextLink',
    );

    final operationType = request.operation.getOperationType();
    final sentryOperation = operationType?.sentryOperation ?? 'unknown';
    final sentryType = operationType?.sentryType;

    final span = _startSpan(
      'GraphQL: "${request.operation.operationName ?? 'unnamed'}" $sentryType',
      sentryOperation,
      shouldStartTransaction,
    );
    return forward!(request).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        final hasGraphQlError = data.errors?.isNotEmpty ?? false;
        if (graphQlErrorsMarkTransactionAsFailed && hasGraphQlError) {
          unawaited(span?.finish(status: const SpanStatus.unknownError()));
        } else {
          unawaited(span?.finish(status: const SpanStatus.ok()));
        }

        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        // Error handling can be significantly improved after
        // https://github.com/gql-dart/gql/issues/361
        // is done.
        // The correct `SpanStatus` can be set on
        // `HttpLinkResponseContext.statusCode` or
        // `DioLinkResponseContext.statusCode`
        span?.throwable = error;
        unawaited(span?.finish(status: const SpanStatus.unknownError()));

        sink.addError(error, stackTrace);
      },
    ));
  }

  InstrumentationSpan? _startSpan(
    String description,
    String op,
    bool shouldStartTransaction,
  ) {
    final parentSpan = _spanFactory.getSpan(_hub);
    if (parentSpan == null && shouldStartTransaction) {
      // Start a new transaction - InstrumentationSpan doesn't support this
      // so we use the legacy API and wrap it
      final transaction = _hub.startTransaction(description, op, bindToScope: true);
      return LegacyInstrumentationSpan(transaction);
    } else if (parentSpan != null) {
      return _spanFactory.createSpan(parentSpan, op, description: description);
    }
    return null;
  }
}
```

**Step 3: Run tests**

Run: `cd packages/link && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/link/lib/src/sentry_tracing_link.dart
git commit -m "$(cat <<'EOF'
feat(link): migrate SentryTracingLink to InstrumentationSpan

- Use InstrumentationSpanFactory for child span creation
- Keep legacy API for transaction creation (when shouldStartTransaction=true)
- Wrap transactions in LegacyInstrumentationSpan for unified interface

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5.2: Migrate SentryRequestSerializer to InstrumentationSpan

**Files:**
- Modify: `packages/link/lib/src/sentry_request_serializer.dart`

**Step 1: Read current implementation**

Read the file at `packages/link/lib/src/sentry_request_serializer.dart`.

**Step 2: Update the file**

```dart
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

class SentryRequestSerializer implements RequestSerializer {
  SentryRequestSerializer({RequestSerializer? inner, Hub? hub})
      : inner = inner ?? const RequestSerializer(),
        _hub = hub ?? HubAdapter() {
    _spanFactory = _hub.options.spanFactory;
  }

  final RequestSerializer inner;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  Map<String, dynamic> serializeRequest(Request request) {
    final parentSpan = _spanFactory.getSpan(_hub);
    final span = _spanFactory.createSpan(
      parentSpan,
      'serialize.http.client',
      description: 'GraphGL request serialization',
    );

    Map<String, dynamic> result;
    try {
      result = inner.serializeRequest(request);
      span?.status = const SpanStatus.ok();
    } catch (e) {
      span?.status = const SpanStatus.unknownError();
      span?.throwable = e;
      rethrow;
    } finally {
      unawaited(span?.finish());
    }
    return result;
  }
}
```

**Step 3: Run tests**

Run: `cd packages/link && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/link/lib/src/sentry_request_serializer.dart
git commit -m "$(cat <<'EOF'
feat(link): migrate SentryRequestSerializer to InstrumentationSpan

- Use InstrumentationSpanFactory instead of hub.getSpan()?.startChild()

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5.3: Migrate SentryResponseParser to InstrumentationSpan

**Files:**
- Modify: `packages/link/lib/src/sentry_response_parser.dart`

**Step 1: Read current implementation**

Read the file at `packages/link/lib/src/sentry_response_parser.dart`.

**Step 2: Update the file**

```dart
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

class SentryResponseParser implements ResponseParser {
  SentryResponseParser({ResponseParser? inner, Hub? hub})
      : inner = inner ?? const ResponseParser(),
        _hub = hub ?? HubAdapter() {
    _spanFactory = _hub.options.spanFactory;
  }

  final ResponseParser inner;
  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  @override
  Response parseResponse(Map<String, dynamic> body) {
    final parentSpan = _spanFactory.getSpan(_hub);
    final span = _spanFactory.createSpan(
      parentSpan,
      'serialize.http.client',
      description: 'Response deserialization '
          'from JSON map to Response object',
    );

    Response result;
    try {
      result = inner.parseResponse(body);
      span?.status = const SpanStatus.ok();
    } catch (e) {
      span?.status = const SpanStatus.unknownError();
      span?.throwable = e;
      rethrow;
    } finally {
      unawaited(span?.finish());
    }
    return result;
  }

  @override
  GraphQLError parseError(Map<String, dynamic> error) =>
      inner.parseError(error);

  @override
  ErrorLocation parseLocation(Map<String, dynamic> location) =>
      inner.parseLocation(location);
}
```

**Step 3: Run tests**

Run: `cd packages/link && dart test`
Expected: All tests pass

**Step 4: Commit**

```bash
git add packages/link/lib/src/sentry_response_parser.dart
git commit -m "$(cat <<'EOF'
feat(link): migrate SentryResponseParser to InstrumentationSpan

- Use InstrumentationSpanFactory instead of hub.getSpan()?.startChild()

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5.4: Run Full Link Test Suite

**Files:**
- Test: `packages/link/test/`

**Step 1: Run all link tests**

Run: `cd packages/link && dart test`
Expected: All tests pass

**Step 2: Run analyze**

Run: `cd packages/link && dart analyze`
Expected: No issues found

---

## Final Verification

### Task 6.1: Run All Package Tests

**Step 1: Run hive tests**

Run: `cd packages/hive && dart test`
Expected: All tests pass

**Step 2: Run isar tests**

Run: `cd packages/isar && dart test`
Expected: All tests pass

**Step 3: Run file tests**

Run: `cd packages/file && dart test`
Expected: All tests pass

**Step 4: Run supabase tests**

Run: `cd packages/supabase && dart test`
Expected: All tests pass

**Step 5: Run link tests**

Run: `cd packages/link && dart test`
Expected: All tests pass

---

### Task 6.2: Run Static Analysis on All Packages

**Step 1: Analyze hive**

Run: `cd packages/hive && dart analyze`
Expected: No issues found

**Step 2: Analyze isar**

Run: `cd packages/isar && dart analyze`
Expected: No issues found

**Step 3: Analyze file**

Run: `cd packages/file && dart analyze`
Expected: No issues found

**Step 4: Analyze supabase**

Run: `cd packages/supabase && dart analyze`
Expected: No issues found

**Step 5: Analyze link**

Run: `cd packages/link && dart analyze`
Expected: No issues found

---

## Notes on InstrumentationSpan/SpanFactory Adjustments

Based on the exploration, the current `InstrumentationSpan` and `InstrumentationSpanFactory` interfaces are **sufficient** for the migration:

1. **No changes needed to core interfaces** - The existing methods (`createSpan`, `getSpan`, `setData`, `setTag`, `status`, `throwable`, `origin`, `finish`) cover all use cases.

2. **Sync operations** - The `finish()` method returns `Future<void>`, which works for sync operations via fire-and-forget pattern (calling without await). This is the same pattern used in legacy code.

3. **Transaction creation** - For the `link` package's `shouldStartTransaction` feature, we continue using `hub.startTransaction()` directly and wrap the result in `LegacyInstrumentationSpan`. This is acceptable because transaction creation is a special case that the factory pattern doesn't need to support.

4. **Null safety** - The factory pattern provides cleaner null handling via `createSpan` returning `null` when parent is null, eliminating the need for `?.` chaining throughout the code.
