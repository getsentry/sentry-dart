# Standalone Extended App Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lifecycle-equivalent Extend App Start APIs for standalone App Start traces using V1 spans in static mode and V2 spans in streaming mode.

**Architecture:** Publish the active internal `AppStartTrace` through Flutter options and route the public API to it. Each lifecycle-specific trace creates its native extension span and temporarily observes span lifecycle events to clean up only that extension subtree; generic `SentryTracer` and `IdleRecordingSentrySpanV2` behavior remains unchanged.

**Tech Stack:** Dart 3.9.2, Flutter 3.35.6, `package:test`, Flutter test, Sentry V1 tracing, Sentry V2 streaming spans.

## Global Constraints

- Implement only opt-in standalone App Start; do not extend legacy `ui.load`.
- Support both `SentryTraceLifecycle.static` and `SentryTraceLifecycle.stream`.
- Use `app.start.extended` and `Extended App Start`.
- The first successful `extendAppStart()` call wins; unsupported, duplicate, and late calls are no-ops.
- Use one SDK-clock timestamp as the authoritative extension end.
- Cancel open extension descendants leaf-first at that timestamp, then finish the extension successfully at the same timestamp.
- Do not finish or force-finish the App Start root from the extension API.
- The measurement endpoint is `max(firstFrameEnd, extensionEnd)`, independent of a later root end.
- Suppress the duration/value when a requested extension reaches the root deadline unfinished.
- Keep extension-specific behavior out of core idle-span and tracer implementations.
- Return lifecycle-specific no-op spans from the getter for the inactive lifecycle.
- Do not edit `CHANGELOG.md`.
- Do not commit or push unless the user explicitly requests it.

**Design reference:** `docs/superpowers/specs/2026-07-22-standalone-extended-app-start-design.md`

---

### Task 1: Define the extension contract and public constants

**Files:**
- Modify: `packages/dart/lib/src/constants.dart`
- Modify: `packages/flutter/lib/src/app_start/standalone/app_start_trace.dart`
- Test: `packages/flutter/test/app_start/standalone/standalone_app_start_lifecycle_test.dart`

**Interfaces:**
- Produces: `SentrySpanOperations.appStartExtended`
- Produces: `AppStartTrace.tryExtend(DateTime)`
- Produces: `AppStartTrace.extendedSpan`
- Produces: `AppStartTrace.extendedSpanV2`
- Produces: `AppStartTrace.finishExtended(DateTime)`

- [ ] **Step 1: Add a failing contract test**

Add a local fake `AppStartTrace` to the lifecycle test and assert that the
contract can represent both getter types and receives an explicit extension
finish timestamp:

```dart
final class FakeAppStartTrace implements AppStartTrace {
  DateTime? extensionStart;
  DateTime? extensionEnd;

  @override
  ISentrySpan get extendedSpan => NoOpSentrySpan();

  @override
  SentrySpanV2 get extendedSpanV2 => const NoOpSentrySpanV2();

  @override
  bool tryExtend(DateTime startTimestamp) {
    extensionStart = startTimestamp;
    return true;
  }

  @override
  Future<void> finishExtended(DateTime endTimestamp) async {
    extensionEnd = endTimestamp;
  }

  @override
  void recordFirstFrame(DateTime endTimestamp) {}

  @override
  void finish(DateTime endTimestamp) {}

  @override
  void close() {}
}
```

- [ ] **Step 2: Run the test to verify the interface fails to compile**

Run from `packages/flutter`:

```bash
fvm flutter test test/app_start/standalone/standalone_app_start_lifecycle_test.dart
```

Expected: compilation fails because the extension members do not exist on
`AppStartTrace`.

- [ ] **Step 3: Add the operation and trace interface**

Add to `SentrySpanOperations`:

```dart
static const appStartExtended = 'app.start.extended';
```

Add the detailed V2 cancellation reason:

```dart
static const String cancelled = 'cancelled';
```

to `SentrySpanStatusMessages`. This intentionally differs from
`SentryIdleSpanFinishReasons.cancelled`: the former describes span status,
while the latter describes why an idle root finished.

Add to `app_start_trace.dart`, importing `package:sentry/sentry.dart`:

```dart
@internal
const standaloneExtendedAppStartName = 'Extended App Start';

abstract interface class AppStartTrace {
  bool tryExtend(DateTime startTimestamp);

  ISentrySpan get extendedSpan;

  SentrySpanV2 get extendedSpanV2;

  Future<void> finishExtended(DateTime endTimestamp);

  void recordFirstFrame(DateTime endTimestamp);

  void finish(DateTime endTimestamp);

  FutureOr<void> close();
}
```

- [ ] **Step 4: Add temporary no-op implementations**

Implement the new members in `StaticAppStartTrace` and
`StreamingAppStartTrace` with `false`, the correct no-op span, and a completed
future. These temporary implementations keep the package compiling until
Tasks 3 and 4 replace them.

- [ ] **Step 5: Run the focused test**

```bash
fvm flutter test test/app_start/standalone/standalone_app_start_lifecycle_test.dart
```

Expected: PASS.

---

### Task 2: Route the public API to the active standalone trace

**Files:**
- Modify: `packages/flutter/lib/src/sentry_flutter_options.dart`
- Modify: `packages/flutter/lib/src/app_start/standalone/standalone_app_start_lifecycle.dart`
- Modify: `packages/flutter/lib/src/sentry_flutter.dart`
- Test: `packages/flutter/test/sentry_flutter_test.dart`
- Test: `packages/flutter/test/app_start/standalone/standalone_app_start_lifecycle_test.dart`

**Interfaces:**
- Consumes: the `AppStartTrace` extension contract from Task 1
- Produces: `SentryFlutter.extendAppStart()`
- Produces: `SentryFlutter.getExtendedAppStartSpan()`
- Produces: `SentryFlutter.getExtendedAppStartSpanV2()`
- Produces: `SentryFlutter.finishExtendedAppStart()`

- [ ] **Step 1: Write failing public API tests**

Use a fake trace installed into `SentryFlutterOptions` and a fixed clock.
Cover:

```dart
test('extendAppStart forwards one SDK clock timestamp', () {
  SentryFlutter.extendAppStart();
  expect(trace.extensionStart, DateTime.utc(2024, 1, 1, 12));
});

test('getters return their lifecycle-specific spans', () {
  expect(SentryFlutter.getExtendedAppStartSpan(), same(trace.extendedSpan));
  expect(SentryFlutter.getExtendedAppStartSpanV2(), same(trace.extendedSpanV2));
});

test('finishExtendedAppStart forwards one SDK clock timestamp', () async {
  await SentryFlutter.finishExtendedAppStart();
  expect(trace.extensionEnd, DateTime.utc(2024, 1, 1, 12));
});

test('APIs are safe without an active trace', () async {
  options.standaloneAppStartTrace = null;
  SentryFlutter.extendAppStart();
  expect(SentryFlutter.getExtendedAppStartSpan(), isA<NoOpSentrySpan>());
  expect(
    SentryFlutter.getExtendedAppStartSpanV2(),
    isA<NoOpSentrySpanV2>(),
  );
  await SentryFlutter.finishExtendedAppStart();
});
```

- [ ] **Step 2: Run the public API tests and confirm failure**

```bash
fvm flutter test test/sentry_flutter_test.dart
```

Expected: compilation fails because the options slot and public methods do not
exist.

- [ ] **Step 3: Publish and clear the active trace**

Add an internal nullable `AppStartTrace` slot to `SentryFlutterOptions`.
When `StandaloneAppStartLifecycle.start()` successfully creates `_trace`, set
the slot to that same instance. In `close()`, clear it only if it is identical
to the trace being closed:

```dart
if (identical(options?.standaloneAppStartTrace, trace)) {
  options?.standaloneAppStartTrace = null;
}
```

Add lifecycle tests proving successful publication, clearing on close, and
preservation of a replacement trace.

- [ ] **Step 4: Implement the public methods**

Resolve `Sentry.currentHub.options`, require `SentryFlutterOptions`, and
delegate:

```dart
static void extendAppStart() {
  final options = Sentry.currentHub.options;
  if (options is SentryFlutterOptions) {
    options.standaloneAppStartTrace?.tryExtend(options.clock());
  }
}

static ISentrySpan getExtendedAppStartSpan() {
  final options = Sentry.currentHub.options;
  return options is SentryFlutterOptions
      ? options.standaloneAppStartTrace?.extendedSpan ?? NoOpSentrySpan()
      : NoOpSentrySpan();
}

static SentrySpanV2 getExtendedAppStartSpanV2() {
  final options = Sentry.currentHub.options;
  return options is SentryFlutterOptions
      ? options.standaloneAppStartTrace?.extendedSpanV2 ??
          const NoOpSentrySpanV2()
      : const NoOpSentrySpanV2();
}

static Future<void> finishExtendedAppStart() async {
  final options = Sentry.currentHub.options;
  if (options is SentryFlutterOptions) {
    final trace = options.standaloneAppStartTrace;
    if (trace != null) {
      await trace.finishExtended(options.clock());
    }
  }
}
```

- [ ] **Step 5: Run the public and lifecycle tests**

```bash
fvm flutter test test/sentry_flutter_test.dart test/app_start/standalone/standalone_app_start_lifecycle_test.dart
```

Expected: PASS.

---

### Task 3: Implement static/V1 extension semantics

**Files:**
- Modify: `packages/flutter/lib/src/app_start/standalone/static_app_start_trace.dart`
- Test: `packages/flutter/test/app_start/standalone/static_app_start_trace_test.dart`

**Interfaces:**
- Consumes: `SentryTracer`, `OnSpanStart`, and `OnSpanFinish`
- Produces: a V1 `ISentrySpan` extension and deterministic async completion

- [ ] **Step 1: Write failing creation and getter tests**

Cover one extension before first frame, rejection after first frame, duplicate
rejection, extension metadata, and the V2 no-op getter:

```dart
expect(trace.tryExtend(extensionStart), isTrue);
final extension = trace.extendedSpan;
expect(extension, isA<SentrySpan>());
expect(extension.context.operation, SentrySpanOperations.appStartExtended);
expect(extension.context.description, standaloneExtendedAppStartName);
expect(extension.startTimestamp, extensionStart);
expect(trace.extendedSpanV2, isA<NoOpSentrySpanV2>());
expect(trace.tryExtend(extensionStart), isFalse);
```

- [ ] **Step 2: Run the static test and confirm failure**

```bash
fvm flutter test test/app_start/standalone/static_app_start_trace_test.dart
```

Expected: FAIL because the temporary implementation returns no-op spans.

- [ ] **Step 3: Create the extension and observe its subtree**

Add state for the extension, all observed extension descendants keyed by
`SpanId`, extension completion, and re-entrancy protection. Create the child
through `_root.startChild`, set origin `auto.app.start`, and register temporary
`OnSpanStart`/`OnSpanFinish` callbacks.

Use each V1 span's `context.parentSpanId` to include only spans whose parent is
the extension or an already-known extension descendant. Keep completed entries
until cleanup so depth can still be calculated.

- [ ] **Step 4: Write failing leaf-first cleanup tests**

Build `extension -> child -> grandchild`, leave both descendants open, and call
`finishExtended` with a fixed timestamp. Record `OnSpanFinish` ordering and
assert:

```dart
expect(finishOrder, [grandchild.context.spanId, child.context.spanId]);
expect(grandchild.status, SpanStatus.cancelled());
expect(child.status, SpanStatus.cancelled());
expect(extension.status, SpanStatus.ok());
expect(grandchild.endTimestamp, extensionEnd);
expect(child.endTimestamp, extensionEnd);
expect(extension.endTimestamp, extensionEnd);
```

Also finish one descendant before the API call and assert its original status
and timestamp are preserved.

- [ ] **Step 5: Implement static cleanup**

At `finishExtended(endTimestamp)`:

1. Normalize `endTimestamp` to UTC and store it once.
2. Sort open descendants by parent depth descending.
3. Await `finish(status: SpanStatus.cancelled(), endTimestamp: timestamp)` for
   each descendant.
4. Set and finish the extension with `SpanStatus.ok()` at the same timestamp.
5. Unregister the temporary callbacks.

Do not call `_root.finish()` or `_root.scheduleFinish()` here.

When `OnSpanFinish` reports that the extension was finished directly, use its
`endTimestamp` to run the same descendant cleanup. Set the extension status to
`SpanStatus.ok()` when it is created so direct `finish()` has the same default
status.

- [ ] **Step 6: Write failing measurement-independence tests**

Cover:

- extension finish after first frame;
- extension finish before first frame;
- a later unrelated root child;
- a later root finish timestamp;
- requested but unfinished extension at deadline.

Assert that the measurement is based on:

```dart
final measurementEnd = extensionEnd.isAfter(naturalEnd)
    ? extensionEnd
    : naturalEnd;
```

and is absent on an unfinished-extension deadline.

- [ ] **Step 7: Implement static measurement state**

Separate the natural first-frame timestamp from the authoritative extension
timestamp. During `_enrichAndComplete`, emit the measurement only when no
extension was requested or the extension completed successfully. Use the later
of natural end and extension end; never use `_root.endTimestamp`.

Keep the existing 30-second root deadline and root-wide descendant completion
inside `StaticAppStartTrace`; do not modify `SentryTracer`.

- [ ] **Step 8: Run the static tests**

```bash
fvm flutter test test/app_start/standalone/static_app_start_trace_test.dart
```

Expected: PASS.

---

### Task 4: Implement streaming/V2 extension semantics

**Files:**
- Modify: `packages/flutter/lib/src/app_start/standalone/streaming_app_start_trace.dart`
- Test: `packages/flutter/test/app_start/standalone/streaming_app_start_trace_test.dart`

**Interfaces:**
- Consumes: `Hub.startInactiveSpan`, `OnSpanStartV2`, and `OnSpanEndV2`
- Produces: a V2 `SentrySpanV2` extension with behavior equivalent to Task 3

- [ ] **Step 1: Write failing creation and getter tests**

Assert the extension is a `RecordingSentrySpanV2`, is parented to the detached
App Start idle root, and carries:

```dart
{
  SemanticAttributesConstants.sentryOp:
      SentryAttribute.string(SentrySpanOperations.appStartExtended),
  SemanticAttributesConstants.sentryOrigin:
      SentryAttribute.string(SentryTraceOrigins.autoAppStart),
}
```

Assert the static getter returns `NoOpSentrySpan`.

- [ ] **Step 2: Run the streaming test and confirm failure**

```bash
fvm flutter test test/app_start/standalone/streaming_app_start_trace_test.dart
```

Expected: FAIL because the temporary implementation returns no-op spans.

- [ ] **Step 3: Create the V2 extension and observe its subtree**

Create the extension with `Hub.startInactiveSpan`, explicit `_root` parent,
call-time timestamp, name `Extended App Start`, and the required operation and
origin attributes.

Register temporary `OnSpanStartV2`/`OnSpanEndV2` callbacks. A candidate belongs
to the extension subtree when walking its `RecordingSentrySpanV2.parentSpan`
chain reaches the extension. Keep this extension-specific observer in
`StreamingAppStartTrace`; do not expose or modify the idle root's private
active-descendant map.

- [ ] **Step 4: Write failing V2 leaf-first cleanup tests**

Build a nested subtree with explicit `parentSpan` values and assert all open
descendants end leaf-first at the API timestamp. V2 cancellation is represented
as:

```dart
span.status = SentrySpanStatusV2.ok;
span.setAttribute(
  SemanticAttributesConstants.sentryStatusMessage,
  SentryAttribute.string(SentrySpanStatusMessages.cancelled),
);
span.end(endTimestamp: extensionEnd);
```

Assert the extension ends with `SentrySpanStatusV2.ok` at that same timestamp.
Assert already-ended descendants retain their status and timestamp.
This `ok` plus `cancelled` message mapping matches JavaScript simple-status
normalization.

- [ ] **Step 5: Implement V2 cleanup**

Sort open tracked descendants by parent depth descending, apply the V2
cancelled representation, and end them at the authoritative timestamp. Then
set the extension to `ok`, end it at the same timestamp, and unregister the
temporary callbacks.

When `OnSpanEndV2` reports direct extension completion, use the extension's
actual end timestamp to invoke the same remaining-descendant cleanup.

Do not call `_root.end()` from extension completion.

- [ ] **Step 6: Write failing V2 measurement tests**

Mirror Task 3's natural-end floor, later unrelated child, later root end,
direct extension end, and unfinished deadline cases. Assert
`app.vitals.start.value` and the cold/warm compatibility value use the
authoritative extension endpoint rather than the root endpoint.

- [ ] **Step 7: Implement V2 measurement state**

During `_processSpan`, emit duration attributes only if no extension was
requested or it completed successfully. Use
`max(naturalEnd, extensionEnd)`. Keep type, screen, and segment-name attributes
on deadline even when duration is omitted.

Leave `IdleRecordingSentrySpanV2` unchanged; it continues to own root-wide idle
waiting, trim behavior, and final timeout.

- [ ] **Step 8: Run the streaming tests**

```bash
fvm flutter test test/app_start/standalone/streaming_app_start_trace_test.dart
```

Expected: PASS.

---

### Task 5: Verify lifecycle parity and document the API

**Files:**
- Modify: `packages/flutter/test/app_start/standalone/standalone_app_start_lifecycle_test.dart`
- Modify: `packages/flutter/test/sentry_flutter_test.dart`
- Modify: `docs/standalone-app-start-spec.md`
- Modify: `packages/flutter/example/lib/main.dart`

**Interfaces:**
- Consumes: all public and lifecycle-specific behavior from Tasks 1–4
- Produces: parity coverage and user-facing usage guidance

- [ ] **Step 1: Add lifecycle-level parity tests**

Run the same scenario once with static tracing and once with streaming:

1. Start standalone App Start.
2. Extend before first frame.
3. Create nested extension descendants.
4. Record first frame.
5. Finish extended App Start.
6. Allow the root lifecycle to complete.

Assert one App Start root, one extension child, matching timestamps,
cancelled descendants, successful extension, and equivalent measurement
duration.

- [ ] **Step 2: Add no-op and cleanup coverage**

Cover calls before initialization, standalone disabled, unsampled App Start,
after first frame, after extension completion, after lifecycle close, repeated
finish calls, and reinitialization. Verify wrong-lifecycle getters always return
their typed no-op span.

- [ ] **Step 3: Run the public and standalone suites**

```bash
fvm flutter test test/sentry_flutter_test.dart test/app_start/standalone
```

Expected: PASS.

- [ ] **Step 4: Update standalone documentation**

Remove “Extended app-start APIs” from the non-goals in
`docs/standalone-app-start-spec.md` and add:

```dart
SentryFlutter.extendAppStart();
final span = SentryFlutter.getExtendedAppStartSpan();

final child = span.startChild(
  'app.init',
  description: 'Fetch remote config',
);
await fetchRemoteConfig();
await child.finish();

await SentryFlutter.finishExtendedAppStart();
```

Document `getExtendedAppStartSpanV2()` for streaming tracing, the first-frame
floor, child cancellation on finish, the 30-second deadline, and standalone-only
scope.

- [ ] **Step 5: Add or update the Flutter example**

Add a concise example in `packages/flutter/example/lib/main.dart` that extends
App Start around an asynchronous initialization operation and always finishes
the extension in `finally`.

- [ ] **Step 6: Format and analyze only changed Dart files**

From `packages/flutter`:

```bash
fvm dart format lib/src/app_start/standalone/app_start_trace.dart lib/src/app_start/standalone/standalone_app_start_lifecycle.dart lib/src/app_start/standalone/static_app_start_trace.dart lib/src/app_start/standalone/streaming_app_start_trace.dart lib/src/sentry_flutter.dart lib/src/sentry_flutter_options.dart test/app_start/standalone/standalone_app_start_lifecycle_test.dart test/app_start/standalone/static_app_start_trace_test.dart test/app_start/standalone/streaming_app_start_trace_test.dart test/sentry_flutter_test.dart example/lib/main.dart
fvm flutter analyze lib/src/app_start/standalone lib/src/sentry_flutter.dart lib/src/sentry_flutter_options.dart
```

Expected: formatting exits 0 and analysis reports no issues.

- [ ] **Step 7: Run final focused verification**

From `packages/flutter`:

```bash
fvm flutter test test/app_start/standalone test/sentry_flutter_test.dart
```

From `packages/dart`:

```bash
fvm dart test test/constants_test.dart
```

Expected: all tests pass. If `test/constants_test.dart` does not exercise
operation constants, run `fvm dart analyze lib/src/constants.dart` instead.

## Self-Review

- Every requirement in the design is assigned to Tasks 2–5.
- V1 and V2 signatures remain distinct and type-correct.
- Extension-specific descendant cleanup is confined to Flutter App Start trace
  implementations.
- Root lifecycle, idle tracking, and deadline ownership remain unchanged.
- The authoritative API-call timestamp, first-frame floor, and later root end
  are tested independently.
- No task edits `CHANGELOG.md`, commits, or pushes.
