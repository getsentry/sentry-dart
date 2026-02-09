# Implementation Plan: SpanV2 Integration Tests for Integration Packages

## Overview

Add high-value integration tests (1-2 per integration) to verify the new span factory and streaming span implementation (spanv2) works correctly across all integration packages. The tests will be minimal but comprehensive, focusing on verifying spans are created and buffered.

## Architecture Context

### SpanV2 System Components

1. **StreamingInstrumentationSpanFactory** - Creates spans using `Hub.startSpan()` with `RecordingSentrySpanV2`
2. **StreamingInstrumentationSpan** - Wraps `SentrySpanV2` and converts legacy API to new API
3. **RecordingSentrySpanV2** - Core span implementation with `OnSpanEndCallback` for buffering
4. **SpanFactoryIntegration** - Sets up the correct factory based on `traceLifecycle` setting

### How Spans Are Captured for Testing

When `traceLifecycle = SentryTraceLifecycle.streaming`:
- Hub.startSpan() creates `RecordingSentrySpanV2` instances
- When span.end() is called, the `OnSpanEndCallback` is invoked
- The callback is `Hub.captureSpan()`, which processes spans through the telemetry processor
- Tests can intercept spans by providing a custom `telemetryProcessor`

## Implementation Strategy

### Phase 1: Create `_sentry_testing` Package

Create a new internal package for shared test utilities that can be imported by all integration packages.

**Directory**: `packages/_sentry_testing/`

**Package Structure**:
```
packages/_sentry_testing/
├── lib/
│   ├── _sentry_testing.dart       # Main export
│   └── src/
│       └── fake_telemetry_processor.dart
├── test/
│   └── fake_telemetry_processor_test.dart  # Test the test utilities
├── pubspec.yaml
└── README.md
```

**Why `_sentry_testing`**:
- `_` prefix follows Dart convention for internal/private packages
- Pub.dev rejects packages starting with `_` - built-in safety against accidental publishing
- Clear purpose: testing utilities only
- Namespace consistency: part of `sentry_*` family but clearly internal

#### 1.1 Create Package Files

**File**: `packages/_sentry_testing/pubspec.yaml`

```yaml
name: _sentry_testing
version: 0.1.0
description: Testing utilities for Sentry Dart/Flutter SDK (internal use only)
publish_to: none

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  sentry:
    path: ../dart
  meta: ^1.11.0
  collection: ^1.18.0  # For firstWhereOrNull

dev_dependencies:
  test: ^1.24.0
```

**File**: `packages/_sentry_testing/README.md`

```markdown
# _sentry_testing

Internal testing utilities for the Sentry Dart/Flutter SDK monorepo.

> ⚠️ **Internal Use Only**
> This package is for use within the Sentry SDK development only.
> It is not published and should not be used in external projects.

## Contents

- `FakeTelemetryProcessor` - Capture spans for verification in tests
- Assertion helpers for span testing

## Usage

Add to your integration package's `dev_dependencies`:

\`\`\`yaml
dev_dependencies:
  _sentry_testing:
    path: ../_sentry_testing
\`\`\`

Import in tests:

\`\`\`dart
import 'package:_sentry_testing/_sentry_testing.dart';
\`\`\`
```

#### 1.2 FakeTelemetryProcessor Implementation

**File**: `packages/_sentry_testing/lib/src/fake_telemetry_processor.dart`

A fake implementation of the telemetry processor that captures spans for assertions:

```dart
import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

/// Fake telemetry processor that captures spans for test assertions.
///
/// Usage:
/// ```dart
/// final processor = FakeTelemetryProcessor();
/// final options = SentryOptions()
///   ..telemetryProcessor = processor.call;
/// ```
class FakeTelemetryProcessor {
  final List<SentrySpan> capturedSpans = [];

  Future<void> call(SentrySpan span) async {
    capturedSpans.add(span);
  }

  void clear() {
    capturedSpans.clear();
  }

  /// Returns all spans that have a parent (not root spans).
  List<SentrySpan> getChildSpans() {
    return capturedSpans.where((s) => s.parentSpan != null).toList();
  }

  /// Finds a span by its operation attribute.
  SentrySpan? findSpanByOperation(String operation) {
    return capturedSpans.firstWhereOrNull(
      (span) => span.attributes['sentry.op']?.value == operation,
    );
  }

  /// Verifies parent-child relationship between two spans.
  void assertSpanIsChildOf(SentrySpan child, SentrySpan parent) {
    expect(child.parentSpan, equals(parent));
    expect(child.traceId, equals(parent.traceId));
  }

  /// Finds all spans that are children of the given parent.
  List<SentrySpan> findChildrenOf(SentrySpan parent) {
    return capturedSpans.where((s) => s.parentSpan == parent).toList();
  }

  /// Waits for all async telemetry processing to complete.
  /// This is necessary because telemetry callbacks are async.
  Future<void> waitForProcessing() async {
    // Small delay to ensure async telemetry callbacks complete.
    // This is a known limitation of the async callback architecture.
    await Future.delayed(Duration(milliseconds: 10));
  }
}
```

#### 1.3 Main Export File

**File**: `packages/_sentry_testing/lib/_sentry_testing.dart`

```dart
/// Internal testing utilities for Sentry Dart/Flutter SDK.
///
/// This library is for internal use only and should not be used outside
/// the Sentry SDK monorepo.
library _sentry_testing;

export 'src/fake_telemetry_processor.dart';
```

### Phase 2: Add `_sentry_testing` to Integration Packages

Each integration package needs to add `_sentry_testing` as a dev dependency.

**Example**: `packages/dio/pubspec.yaml`

```yaml
dev_dependencies:
  _sentry_testing:
    path: ../_sentry_testing
  test: ^1.24.0
  # ... other dev dependencies
```

Repeat for all integration packages: `dio`, `sqflite`, `drift`, `hive`, `isar`, `file`, `supabase`, `link`.

### Phase 3: Implement Tests for Each Integration

**Important**: Tests should verify not just that spans are created, but also that parent-child relationships are correct. This includes:
- Transaction span (root) is the parent of operation spans
- Nested operations create proper span hierarchies (e.g., transaction → query → execution)
- Each child span has the correct parent and shares the same traceId
- Span IDs are unique and properly formatted

Create `spanv2_integration_test.dart` in each integration package test directory with 1-2 tests. Each test file will import from `_sentry_testing`:

```dart
import 'package:_sentry_testing/_sentry_testing.dart';
```

#### 3.1 Dio (packages/dio/test/)

**Test 1**: HTTP GET creates spanv2
- Start transaction span
- Execute HTTP GET request via TracingClientAdapter
- Assert span captured with operation `http.client`
- Verify attributes: `http.request.method`, `url`, `http.response.status_code`, `sentry.origin`
- Assert status `ok`
- Verify span is child of transaction span

**Test 2**: HTTP error creates spanv2 with error status
- Start transaction span
- Trigger network error
- Assert span status is `error`

#### 3.2 Sqflite (packages/sqflite/test/)

**Test 1**: Database query creates spanv2
- Start transaction span
- Execute query via SentryDatabase
- Assert span captured with operation `db.sql.query`
- Verify attributes: `db.system`, `db.name`, `sentry.origin`
- Assert status `ok`
- Verify span is child of transaction span

**Test 2**: Database transaction creates nested span hierarchy
- Start transaction span
- Execute transaction with queries inside (e.g., batch operations)
- Assert db transaction span captured with operation `db.sql.transaction`
- Assert query spans captured within db transaction
- **Verify hierarchy**: queries are children of db transaction, db transaction is child of transaction span
- Assert status `ok`

#### 3.3 Drift (packages/drift/test/)

**Test 1**: Drift query creates spanv2
- Start transaction span
- Execute query via Drift interceptor
- Assert span captured with operation `db.sql.query`
- Verify attributes: `db.system`, `db.name`, `sentry.origin`
- Verify span is child of transaction span

**Test 2**: Drift transaction creates nested span hierarchy
- Start transaction span
- Execute transaction with queries inside
- Assert transaction span captured with operation `db.sql.transaction`
- Assert query spans captured with operation `db.sql.query`
- **Verify hierarchy**: queries are children of transaction, transaction is child of root
- Verify all spans share the same traceId

#### 3.4 Hive (packages/hive/test/)

**Test 1**: Box.get() creates spanv2
- Start transaction span
- Execute box.get() operation
- Assert span captured with operation `db`
- Verify attributes: `db.system`, `db.name`, `sync`, `sentry.origin`

**Test 2**: Box.put() creates spanv2
- Start transaction span
- Execute box.put() operation
- Assert span captured

#### 3.5 Isar (packages/isar/test/)

**Test 1**: Isar collection query creates spanv2
- Start transaction span
- Execute collection query
- Assert span captured with operation `db`
- Verify attributes: `db.system`, `db.name`, `sentry.origin`

**Test 2**: Isar write transaction creates spanv2
- Start transaction span
- Execute write transaction
- Assert span captured

#### 3.6 File (packages/file/test/)

**Test 1**: File read creates spanv2
- Start transaction span
- Execute file read via SentryFile
- Assert span captured with operation `file.read`
- Verify attributes: `file.path`, `sentry.origin`

**Test 2**: File write creates spanv2
- Start transaction span
- Execute file write
- Assert span captured with operation `file.write`

#### 3.7 Supabase (packages/supabase/test/)

**Test 1**: Supabase query creates spanv2
- Start transaction span
- Execute Supabase query
- Assert span captured with operation matching database operation
- Verify attributes: `db.table`, `db.system`, `sentry.origin`

#### 3.8 Link (packages/link/test/)

**Test 1**: GraphQL query creates spanv2
- Start transaction span
- Execute GraphQL query
- Assert span captured with operation `graphql.query`
- Verify attributes: operation name, `sentry.origin`

**Test 2**: GraphQL mutation creates spanv2
- Start transaction span
- Execute GraphQL mutation
- Assert span captured with operation `graphql.mutation`

### Test Pattern Template

#### Basic Test Pattern (Single Layer)

```dart
import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:test/test.dart';

test('operation creates spanv2', () async {
  final fixture = Fixture();

  // Start transaction span (the "root" of this trace)
  final transactionSpan = fixture.hub.startSpan(
    'test-transaction',
    parentSpan: null,
  );
  fixture.hub.scope.setActiveSpan(transactionSpan);

  // Execute integration operation
  // This should create child spans under the transaction
  // ...

  // End transaction span and wait for async processing
  transactionSpan.end();
  await fixture.processor.waitForProcessing();

  // Assert child span was created
  final childSpans = fixture.processor.getChildSpans();
  expect(childSpans.length, greaterThan(0));

  final span = childSpans.first;
  expect(span.isEnded, isTrue);
  expect(span.status, equals(SentrySpanStatus.ok));

  // Verify operation and attributes
  expect(span.attributes['sentry.op']?.value, equals('expected.operation'));
  expect(span.attributes['key']?.value, equals('value'));

  // Verify parent-child relationship
  expect(span.parentSpan, equals(transactionSpan));
  expect(span.traceId, equals(transactionSpan.traceId));
});
```

#### Nested Span Test Pattern (Multiple Layers)

For integrations that create nested spans (e.g., Drift transactions with queries):

```dart
import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:test/test.dart';

test('transaction creates nested span hierarchy', () async {
  final fixture = Fixture();

  // Start transaction span (the "root" of this trace)
  final transactionSpan = fixture.hub.startSpan(
    'test-transaction',
    parentSpan: null,
  );
  fixture.hub.scope.setActiveSpan(transactionSpan);

  // Execute operation that creates nested spans
  // e.g., db.transaction(() async {
  //   await db.query(...);
  //   await db.query(...);
  // });

  // End transaction span and wait for async processing
  transactionSpan.end();
  await fixture.processor.waitForProcessing();

  // Find spans by operation
  final dbTransactionSpan = fixture.processor.findSpanByOperation('db.sql.transaction');
  final querySpans = fixture.processor.capturedSpans
      .where((s) => s.attributes['sentry.op']?.value == 'db.sql.query')
      .toList();

  // Verify hierarchy: transaction → db.transaction → queries
  expect(dbTransactionSpan, isNotNull);
  expect(dbTransactionSpan!.parentSpan, equals(transactionSpan));
  expect(querySpans.length, greaterThan(0));

  for (final querySpan in querySpans) {
    expect(querySpan.parentSpan, equals(dbTransactionSpan));
    expect(querySpan.traceId, equals(transactionSpan.traceId));
  }

  // Verify all spans share the same trace and have unique span IDs
  final allSpans = [transactionSpan, dbTransactionSpan, ...querySpans];
  final traceId = transactionSpan.traceId;
  final spanIds = <String>{};

  for (final span in allSpans) {
    expect(span.traceId, equals(traceId));
    expect(spanIds.add(span.spanId.toString()), isTrue,
        reason: 'Span IDs must be unique');
  }
});
```

**Key Fixture Pattern for Each Package**:

```dart
import 'package:_sentry_testing/_sentry_testing.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

class Fixture {
  late final Hub hub;
  late final SentryOptions options;
  late final FakeTelemetryProcessor processor;

  Fixture() {
    processor = FakeTelemetryProcessor();
    options = SentryOptions(dsn: 'https://public@example.com/1')
      ..tracesSampleRate = 1.0
      ..traceLifecycle = SentryTraceLifecycle.streaming
      ..automatedTestMode = true
      ..telemetryProcessor = processor.call;
    hub = Hub(options);
  }

  // Integration-specific helper methods
  // e.g., getDio(), getSentryDatabase(), etc.

  /// Clean up resources. Call in tearDown() if needed.
  void dispose() {
    processor.clear();
    hub.close();
  }
}

// Example test setup with cleanup
void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    fixture.dispose();
  });

  test('your test here', () async {
    // Test implementation
  });
}
```

## Critical Files to Modify/Create

### New Package to Create

**`packages/_sentry_testing/`** - Internal testing utilities package

1. `packages/_sentry_testing/pubspec.yaml` - Package configuration
2. `packages/_sentry_testing/README.md` - Package documentation
3. `packages/_sentry_testing/lib/_sentry_testing.dart` - Main export file
4. `packages/_sentry_testing/lib/src/fake_telemetry_processor.dart` - Fake telemetry processor
5. `packages/_sentry_testing/test/fake_telemetry_processor_test.dart` - Tests for test utilities

### Integration Package Modifications

**Update `pubspec.yaml` in each integration package** to add `_sentry_testing` as dev_dependency:

1. `packages/dio/pubspec.yaml`
2. `packages/sqflite/pubspec.yaml`
3. `packages/drift/pubspec.yaml`
4. `packages/hive/pubspec.yaml`
5. `packages/isar/pubspec.yaml`
6. `packages/file/pubspec.yaml`
7. `packages/supabase/pubspec.yaml`
8. `packages/link/pubspec.yaml`

### New Test Files to Create

1. `packages/dio/test/spanv2_integration_test.dart` - Dio integration tests
2. `packages/sqflite/test/spanv2_integration_test.dart` - Sqflite integration tests
3. `packages/drift/test/spanv2_integration_test.dart` - Drift integration tests
4. `packages/hive/test/spanv2_integration_test.dart` - Hive integration tests
5. `packages/isar/test/spanv2_integration_test.dart` - Isar integration tests
6. `packages/file/test/spanv2_integration_test.dart` - File integration tests
7. `packages/supabase/test/spanv2_integration_test.dart` - Supabase integration tests
8. `packages/link/test/spanv2_integration_test.dart` - Link integration tests

### Key Files to Reference (Read-Only)

- `packages/dart/lib/src/tracing/instrumentation/span_factory.dart` - Factory implementation
- `packages/dart/lib/src/tracing/instrumentation/instrumentation_span.dart` - Span wrapper interface
- `packages/dart/lib/src/telemetry/span/recording_sentry_span_v2.dart` - Core span implementation
- `packages/dart/lib/src/hub.dart` - Hub.startSpan() implementation
- `packages/dio/test/tracing_client_adapter_test.dart` - Example of existing tests

## Package-Specific Considerations

### Nested Span Behavior by Package

**Packages with Nested Spans** (should test multi-layer hierarchy):
- **Sqflite**: Transactions contain query/execute operations
- **Drift**: Transactions contain queries, uses transaction stack
- **Dio**: Request may contain serialization sub-spans (via SentryTransformer)

**Packages with Single-Layer Spans** (parent is always root):
- **Hive**: Direct operations (get, put, delete)
- **Isar**: Collection operations
- **File**: File I/O operations
- **Supabase**: HTTP requests (single layer)
- **Link**: GraphQL operations (single layer)

### Dart vs Flutter Packages

**Dart-only** (dio, hive, isar, drift, link):
- Use `dart test` command
- No Flutter dependencies
- Can run on VM only

**Flutter packages** (sqflite, file, supabase):
- Use `flutter test` command
- May require `TestWidgetsFlutterBinding.ensureInitialized()`
- Sqflite needs sqflite_common_ffi for VM testing

### Async vs Sync Operations

**All operations require async processing:**
- Telemetry processor callbacks are always async (even for synchronous span operations)
- Use `await fixture.processor.waitForProcessing()` after transaction span ends
- This helper method encapsulates the necessary delay for async callback completion
- The 10ms delay is a known limitation of the current async callback architecture

**Note**: Both async and sync operations (dio, supabase, sqflite, drift, file, link, hive, isar) need the `waitForProcessing()` call because the telemetry callbacks themselves are async, regardless of whether the instrumented operation is sync or async.

### Mock Requirements

- **Dio**: Use MockHttpClientAdapter (already exists)
- **Sqflite**: Use sqflite_common_ffi or mock Database or use in memory database if possible
- **Drift**: In-memory database
- **Hive**: Temp directory for box storage
- **Isar**: Temp directory for database
- **File**: Temp directory or memory file system
- **Supabase**: Mock HTTP client
- **Link**: Mock GraphQL client/response stream

## Verification Steps

After implementation, verify each package:

1. **Run tests individually**:
   ```bash
   cd packages/<package>/
   dart test test/spanv2_integration_test.dart  # or flutter test
   ```

2. **Verify test output**:
   - All tests pass
   - No interference with existing tests
   - Spans are captured correctly

3. **Run full test suite**:
   ```bash
   cd packages/<package>/
   dart test  # or flutter test
   ```

4. **Verify no regressions**:
   - All existing tests still pass
   - No new warnings or errors

## Success Criteria

For each integration package, tests verify:

1. ✅ **Span Creation**: Child span created during operation
2. ✅ **Span Lifecycle**: Span properly started and ended
3. ✅ **Operation Attribute**: `sentry.op` matches expected operation
4. ✅ **Key Attributes**: Integration-specific attributes present and correct
5. ✅ **Status**: Span status reflects success (`ok`) or failure (`error`)
6. ✅ **Origin**: `sentry.origin` identifies the integration
7. ✅ **Parent Relationship**: Span is child of transaction span (verified via `parentSpan` reference)
8. ✅ **Trace Consistency**: All spans in hierarchy share the same `traceId`
9. ✅ **Span ID Uniqueness**: All spans have unique `spanId` values
10. ✅ **Nested Spans** (where applicable): Multi-layer hierarchies are correctly structured (e.g., transaction → db.transaction → query)

## Benefits of This Approach

- **Minimal**: Only 1-2 tests per package (16 tests total)
- **High Value**: Tests critical span creation/buffering mechanism
- **Independent**: No interference with legacy span tests
- **Reusable**: Shared utilities reduce code duplication
- **Fast**: Integration tests run quickly with minimal setup
- **Comprehensive**: Covers all 8 integration packages
- **Maintainable**: Clear patterns make updates easy

## Implementation Order

Recommended order (simplest to most complex):

### Phase 1: Create `_sentry_testing` Package
1. Create package structure and `pubspec.yaml`
2. Implement `FakeTelemetryProcessor` in `lib/src/`
3. Create main export file `lib/_sentry_testing.dart`
4. Add README.md with usage instructions
5. (Optional) Add tests for the test utilities themselves

### Phase 2: Add Dev Dependencies
6. Update all 8 integration packages' `pubspec.yaml` files to add `_sentry_testing` as dev_dependency
7. Run `dart pub get` or `flutter pub get` in each package to verify dependencies resolve

### Phase 3: Implement Integration Tests (Simplest to Most Complex)
8. **Dio** - HTTP client, simplest integration, good reference implementation
9. **Hive** - Synchronous database operations, straightforward
10. **File** - Simple file I/O operations
11. **Isar** - Database operations, similar to Hive but more features
12. **Sqflite** - Flutter database, may need sqflite_common_ffi for testing
13. **Drift** - More complex database with transaction stacks
14. **Link** - GraphQL with streams, moderate complexity
15. **Supabase** - Most complex, combines HTTP + database semantics

### Phase 4: Validation
16. Run each package's tests individually to verify
17. Run full test suite for each package to check for regressions
18. Run all tests across the monorepo with Melos (if applicable)
