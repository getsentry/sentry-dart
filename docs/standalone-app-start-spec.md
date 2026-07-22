# Standalone App Start

**Status:** Implemented

**Source:** [sentry-dart#3634](https://github.com/getsentry/sentry-dart/issues/3634)

## Problem

Flutter currently represents native app start inside a synthetic initial
`ui.load`. This conflates startup and screen-display telemetry and prevents app
start from having an independent lifecycle and sampling decision.

## Desired outcome

On Android and iOS, users can opt into a standalone `App Start` root. Behavior
is equivalent across static and streaming trace lifecycles while using each
lifecycle's native payload representation.

## Acceptance criteria

- `enableStandaloneAppStartTracing` is experimental, defaults to `false`, and
  does not independently enable tracing.
- When disabled, existing app-start attachment to `ui.load` remains unchanged.
- When enabled, exactly one app-start representation is emitted.
- The root is named `App Start`, uses `app.start`, and has origin
  `auto.app.start`.
- Its natural duration runs from process start to the first frame drawn.
- The root has idle/child-waiting behavior, a 30-second hard deadline, and is
  not bound to scope.
- Existing platform, plugin-registration, setup, and first-frame breakdown
  spans remain direct root children. There is no cold/warm grouping span.
- The normal initial `ui.load` remains an independent sibling root for TTID and
  TTFD and contains no app-start measurement or breakdown.
- Both roots use the propagation context's trace ID while independently using
  the lifecycle-native root sampling path.
- Flutter remains the sole owner of the standalone signal.
- Every foreground standalone event reports `app.vitals.start.screen`, using
  the observed initial route name or the existing `root /` fallback.
- Missing or invalid native timing omits `app.start`; `ui.load` continues
  normally.
- A successful measurement requires a first frame. Headless and background
  app starts are unsupported.

### Lifecycle-specific signals

| Signal | Static lifecycle | Streaming lifecycle |
| --- | --- | --- |
| Duration | `app_start_cold` or `app_start_warm` measurement | `app.vitals.start.value` |
| Type | Lifecycle-native metadata mapped to cold/warm type | `app.vitals.start.type` |
| Compatibility value | Legacy measurement above | Corresponding `app.vitals.start.cold.value` or `.warm.value` |
| Screen | Required lifecycle-native screen metadata | Required `app.vitals.start.screen` |
| Segment identity | Transaction name `App Start` | Segment name `App Start` |

Both lifecycles produce the same observable duration, type, screen, hierarchy,
status, and deduplication behavior in Sentry.

### Extended App Start APIs

Standalone App Start can be extended around asynchronous startup work:

```dart
SentryFlutter.extendAppStart();
final span = SentryFlutter.getExtendedAppStartSpan();

final child = span.startChild(
  'app.init',
  description: 'Fetch remote config',
);

try {
  await fetchRemoteConfig();
  await child.finish();
} finally {
  await SentryFlutter.finishExtendedAppStart();
}
```

When using the streaming trace lifecycle, call
`SentryFlutter.getExtendedAppStartSpanV2()` instead of
`getExtendedAppStartSpan()`.

The extension remains standalone-App-Start-only:

- it is available only for the standalone `App Start` root, not the legacy
  `ui.load`-attached app-start flow;
- its finish timestamp cannot move the measurement earlier than the first
  frame;
- finishing it cancels any still-open extension descendants;
- the root keeps the existing 30-second hard deadline and captures without an
  App Start duration when the extension never completes.

### Deadline behavior

On the hard deadline:

- the standalone event is captured;
- the root and all still-open descendants end as `deadlineExceeded`;
- already completed children retain their existing statuses;
- the duration measurement/value is omitted; and
- type and required screen metadata are retained.

If no first frame arrives, this diagnostic deadline event may still be
captured without a duration vital. This is not headless app-start support.

## Non-goals

- Headless or background app-start measurement.
- Support for macOS, web, Linux, Windows, tvOS, or other platforms.
- A dedicated app-start sampling option.
- Changing flag-off behavior.
- External docs-site changes.
