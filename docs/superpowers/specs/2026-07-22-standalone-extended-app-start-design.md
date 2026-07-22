# Standalone Extended App Start Design

**Source:** [sentry-dart#3767](https://github.com/getsentry/sentry-dart/issues/3767)

## Scope

Add the Extend App Start API only for the opt-in standalone App Start trace.
Support both static (V1) and streaming (V2) trace lifecycles. Extending the
legacy App Start attached to `ui.load` is out of scope.

## Public API

`SentryFlutter` exposes:

- `extendAppStart()`, which creates one `Extended App Start` child with
  operation `app.start.extended`. The child starts at the call timestamp.
- `getExtendedAppStartSpan()`, which returns the active V1 `ISentrySpan` for
  the static lifecycle and a `NoOpSentrySpan` otherwise.
- `getExtendedAppStartSpanV2()`, which returns the active `SentrySpanV2` for
  the streaming lifecycle and a `NoOpSentrySpanV2` otherwise.
- `finishExtendedAppStart()`, which asynchronously finishes the extension for
  whichever trace lifecycle is active.

The first successful `extendAppStart()` call wins. Calls made before a
standalone trace exists, after its natural first-frame completion, after
shutdown, or after an extension has already been requested are no-ops.

## Completion

The timestamp obtained from the SDK clock when `finishExtendedAppStart()` is
called is the authoritative extended App Start endpoint.

At that timestamp, the lifecycle-specific trace:

1. Finds still-open descendants of the extension.
2. Finishes those descendants leaf-first as cancelled.
3. Finishes the extension span as successful.
4. Leaves the App Start root open for its existing wait-for-children, idle,
   and deadline behavior.

V1 represents cancellation with `SpanStatus.cancelled()`. V2 represents it
with `SentrySpanStatusV2.ok` and the `sentry.status.message` attribute set to
`cancelled`. This matches the JavaScript status normalization, which preserves
cancelled as the detailed reason while reducing it to the simple `ok` status.

Directly finishing the returned V1 span or ending the returned V2 span triggers
the same subtree cleanup. Its own end timestamp is used as the authoritative
endpoint.

## Descendant Tracking

Extension-specific behavior stays out of the generic idle span.

The static and streaming App Start trace implementations register temporary
span lifecycle callbacks while an extension is active:

- V1 uses `OnSpanStart` and `OnSpanFinish`.
- V2 uses `OnSpanStartV2` and `OnSpanEndV2`.

Each implementation tracks only the extension subtree, unregistering its
callbacks after completion or close. The existing `SentryTracer` and
`IdleRecordingSentrySpanV2` continue to own root-wide waiting, trimming, and
deadline behavior.

## Measurement

The natural first-frame endpoint remains the minimum App Start endpoint.
Successful extended App Start uses:

`max(natural first-frame endpoint, authoritative extension endpoint)`

The measurement does not use the eventual root end. The root may finish later
because of idle behavior or unrelated children without extending the App Start
measurement.

If an extension is requested but does not finish before the 30-second
deadline, the root is still captured but the App Start duration/value is
omitted. Type and screen metadata remain.

## Lifecycle Equivalence

Static and streaming implementations produce equivalent observable behavior:

- one standalone App Start root;
- one extension child;
- the same start and finish timestamps;
- leaf-first cancellation of open descendants;
- a successful extension status;
- the same measurement endpoint and deadline suppression;
- no direct root force-finish.

The public getters remain lifecycle-specific because `ISentrySpan` and
`SentrySpanV2` do not share a common span API.

## Tests

Both lifecycles cover:

- successful extension before first frame;
- extension finish before and after first frame;
- duplicate and late calls;
- correct getter and wrong-lifecycle no-op getter;
- nested child hierarchy;
- leaf-first cancellation at one timestamp;
- preservation of already-finished descendants;
- direct span finish/end equivalence;
- root finalization occurring later without changing the measurement;
- deadline capture with measurement suppression;
- close and reinitialization cleanup;
- unchanged behavior when extension is unused.
