# Standalone and Extended App Start

**Status:** Implemented

**Sources:** [sentry-dart#3634](https://github.com/getsentry/sentry-dart/issues/3634) and [sentry-dart#3767](https://github.com/getsentry/sentry-dart/issues/3767)

The existing draft implementation is not a source of requirements for this specification.

## Problem

Flutter currently represents native app start inside a synthetic initial `ui.load`. This conflates startup and screen-display telemetry and prevents app start from having an independent lifecycle, sampling decision, and extension window.

Flutter already creates that initial `ui.load`, so app-start loss is not caused simply by a missing navigation transaction. The remaining dependency is valid native timing plus a first rendered frame.

## Desired outcome

On Android and iOS, users can opt into a standalone `App Start` root and optionally extend it for additional initialization work. Behavior is equivalent across static and streaming trace lifecycles while using each lifecycle's native payload representation.

## Acceptance criteria

### Standalone behavior

- `enableStandaloneAppStartTracing` is experimental, defaults to `false`, and does not independently enable tracing.
- When disabled, existing app-start attachment to `ui.load` remains unchanged.
- When enabled, exactly one app-start representation is emitted.
- The root is named `App Start`, uses `app.start`, and has origin `auto.app.start`.
- Its natural duration runs from process start to the first frame drawn.
- The root has idle/child-waiting behavior, a hard deadline, and is not bound to scope.
- Existing platform, plugin-registration, setup, and first-frame breakdown spans remain direct root children. There is no cold/warm grouping span.
- The normal initial `ui.load` is still emitted for TTID/TTFD, but contains no app-start measurement or breakdown.
- `app.start` and `ui.load` are sibling roots using the propagation context's trace ID.
- Flutter remains the sole owner of the standalone signal; native SDK standalone emission cannot create duplicates.
- Every foreground standalone event reports `app.vitals.start.screen` without
  delaying capture. It uses the observed initial route name when available and
  the existing `root /` fallback otherwise; absence of this field is reserved
  for starts with no screen, which this feature does not support.
- Missing or invalid native timing omits `app.start`; `ui.load` continues normally.
- Successful app-start measurement requires a first frame. Headless/background app starts are unsupported.

### Lifecycle-specific signals

| Signal | Static lifecycle | Streaming lifecycle |
| --- | --- | --- |
| Duration | `app_start_cold` or `app_start_warm` measurement | `app.vitals.start.value` |
| Type | Lifecycle-native metadata mapped to cold/warm type | `app.vitals.start.type` |
| Compatibility value | Legacy measurement above | Corresponding `app.vitals.start.cold.value` or `.warm.value` |
| Screen | Required lifecycle-native screen metadata | Required `app.vitals.start.screen` |
| Segment identity | Transaction name `App Start` | Segment name `App Start` |

Both lifecycles must produce the same observable duration, type, screen, hierarchy, status, and deduplication behavior in Sentry.

### Extension behavior

- Extension works only when standalone tracing is enabled and a valid app start is still in progress.
- The first successful `extendAppStart()` call wins. Later calls are no-ops.
- Calls made too late, without an active start, on unsupported platforms, or with the feature disabled are no-ops.
- A successful call creates a visible `Extended App Start` child with operation `app.start.extended`, beginning at call time.
- User-created initialization spans can be nested beneath it.
- In the static lifecycle, `SentryFlutter.getExtendedAppStartSpan()` returns the active extension as `ISentrySpan?`. It returns `null` when the streaming lifecycle is active or after the extension wrapper is finished.
- In the streaming lifecycle, `SentryFlutter.getExtendedAppStartSpanV2()` returns the active extension as `SentrySpanV2?`. It returns `null` when the static lifecycle is active or after the extension wrapper is finished.
- `SentryFlutter.finishExtendedAppStart()` returns `void`, requests the active extension wrapper to finish, and returns immediately. It is a no-op when no extension is active.
- Calling `finishExtendedAppStart()` or directly finishing the lifecycle-specific returned span marks the same wrapper finished and produces the same app-start telemetry.
- Root finalization and capture continue asynchronously; neither finishing path guarantees that capture has completed before returning.
- Finishing ends the wrapper at its recorded finish timestamp; it does not wait
  for initialization spans nested beneath it.
- The root waits for remaining descendants so they are captured, but their
  completion does not move the wrapper end or the app-start measurement.
- To include nested initialization work in the extension window, users finish
  those child spans before finishing the extension wrapper.
- The successful app-start measurement end is the later of:
  - first frame drawn;
  - the extension wrapper's recorded finish timestamp.
- Finishing before first frame cannot shorten natural app start.
- The extended duration remains process start through that successful
  measurement end.

### Deadline behavior

- Every standalone root has one 30-second safety deadline beginning at root
  creation. Extending app start does not move that deadline.
- On deadline:
  - the standalone event is still captured;
  - the root, wrapper, and all still-open descendants end as `deadlineExceeded`;
  - already completed children retain their existing statuses;
  - the app-start duration measurement/value is omitted;
  - type and the required screen metadata are retained.
- If no first frame ever arrives, this diagnostic deadline event may still be captured without a duration vital. This is not headless app-start support.

### Sampling and documentation

- `app.start` and `ui.load` each use the existing lifecycle-native root
  sampling path and are independently evaluated by the normal `tracesSampler`.
- No separate app-start sample-rate option is introduced.
- SDK API documentation and an in-repository usage example are required.
- External docs-site work remains tracked by [sentry-dart#3637](https://github.com/getsentry/sentry-dart/issues/3637).

## Non-goals

- Headless or background app-start measurement.
- Support for macOS, web, Linux, Windows, tvOS, or other platforms.
- Changing flag-off behavior or enabling standalone tracing by default.
- A dedicated app-start sampling option.
- Changing lifecycle-wide incoming trace or inherited-sampling behavior.
- Implicitly extending the app-start measurement when a descendant finishes
  after its extension wrapper.
- External docs-site changes.
- Choosing file layout, internal ownership, or exact phase-span operation taxonomy; those belong to technical design.

The design must leave a clean path for adding future platforms without changing this public contract.

## Open questions

None at the product-requirement level.
