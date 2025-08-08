### TTID/TTFD Refactor Plan

#### Current architecture

- **Navigator-driven timing**: `SentryNavigatorObserver` starts/finishes per-route transactions and drives TTID/TTFD.
- **Trackers**: `TimeToDisplayTracker` orchestrates `TimeToInitialDisplayTracker` and `TimeToFullDisplayTracker` with timers and ad-hoc state.
- **App start**:
  - `NativeAppStartIntegration` + `NativeAppStartHandler` (mobile): captures native start times, creates root transaction, then delegates to `TimeToDisplayTracker` for TTID/TTFD.
  - `GenericAppStartIntegration` (web/desktop): uses frame callbacks to approximate app start and TTID.
- **Options**: `SentryFlutterOptions.timeToDisplayTracker` is a global tracker instance; `enableTimeToFullDisplayTracing` toggles TTFD.

#### Why it’s bad

- **Mixed responsibilities**: span creation, route events, timers, and measurements are spread across observer/integrations/trackers.
- **Implicit state**: global `transactionId`, completers, and timers create hidden, fragile lifecycle coupling.
- **Weak ordering guarantees**: out-of-order calls (e.g., TTFD before TTID) require scattered checks; no central FSM.
- **Manual cleanup**: new route requires remembering to end/abort previous timing; easy to leak timers or overlap spans.
- **Duplication**: app-start and route timing implement similar logic in different places.
- **Testing friction**: hard to mock and assert transitions; behavior depends on global options and Flutter bindings.

#### Solution (clean architecture)

- **Public façade**: `display_timing_controller.dart`
  - Synchronous API for starting app/route timing and ending TTID/TTFD.
  - Owns handle invalidation and minimal policy (e.g., ignore when tracing disabled).
  - TTID is always automatic (app start and routes). No public/manual TTID end APIs; only internal calls from integrations/observer.
- **Core engine with FSM**: `display_transaction_engine.dart`
  - Single authority for spans, timers, and transitions.
  - Guards: illegal transitions assert in debug, log+recover in release.
  - Auto-abort previous timing on new start.
  - Supports two internal slots: `root` (app start) and `route` (per navigation). Multi-navigator is out-of-scope for now.
- **State model**: `display_txn.dart`
  - Sealed states: `Idle` → `Active(ttidOpen: true)` → `Active(ttidOpen: false)` → `Finished`/`Aborted`.
  - Holds `transaction`, child spans (TTID/TTFD), timestamps, timeout.
- **Opaque handles**: `display_handles.dart`
  - `AppStartDisplayHandle`, `RouteDisplayHandle` expose `endTtid()` and `reportFullyDisplayed()`; idempotent and safe after invalidation.
- **Thin integrations**:
  - `SentryNavigatorObserver`: emits route start/abort to controller; keeps breadcrumbs/session logic separate. It MUST synchronously call `addPostFrameCallback` within `didPush` to end TTID for routes (ensures first frame), invoking the route handle’s `endTtid()` inside the callback.
  - `NativeAppStartIntegration` and `GenericAppStartIntegration`: call `startApp()` and then end TTID at the appropriate time; native handler attaches spans/measurements.
- **Dart 3.5 idioms**: sealed classes, pattern matching in transitions, records for small return tuples, final/late final, dependency-injected clock/frame sources.

#### Edge cases to handle

- **Tracing disabled/no sample rate**: engine detects `NoOpSentrySpan` or disabled tracing and no-ops; handles remain functional but do nothing.
- **TTFD before TTID**: engine stores pending TTFD timestamp; completes after TTID or times out.
- **Multiple starts**: `startRoute` while route active → auto-abort previous; logs in release, asserts in debug.
- **Pop without TTID**: aborts with proper status; cancels timers.
- **Timeouts**: TTFD auto-finish after `options.autoFinishAfter` (or per-route override).
- **User never calls `reportFullyDisplayed()`**: timeout path; status `deadlineExceeded`; TTID may still be OK.
- **Replace sequences**: `didReplace(old→new)` acts like `abortCurrent` then `startRoute(new)`.
- **First route `/`**: app-start integration owns root timing and the transaction name remains `root /`; navigator observer skips creating a route transaction for the initial push.
- **Ignored routes**: controller not started for routes listed in `ignoreRoutes`.
- **Multi-navigator/multi-view**: not supported in this iteration. Future extension could map slots per navigator/view.
- **Web sessions**: remain in observer; independent of display timing.
- **Widget binding not initialized**: frame handlers resilient to missing bindings (current `DefaultFrameCallbackHandler` behavior).
- **Automated test mode**: rethrow in debug/test for deterministic failures; log in release.

Additional scenarios

- **Deep links**: Cold-start deep links land in the app-start path (root transaction, TTID via first frame); warm deep links are standard `didPush`/`didReplace` flows.
- **Router 2.0/go_router**: Supported via `SentryNavigatorObserver`; document how to attach it when using router APIs.

#### Notes

- Measurements are set on the transaction when TTID/TTFD finish; spans are children of the route/app transaction.
- Engine owns all timers; controller/integrations are timer-free.
- Public API is synchronous; `finish()` is fire-and-forget with internal error capture.
- Backwards compatibility: `SentryFlutter.currentDisplay()` continues to return a handle that delegates to the controller; legacy `SentryDisplay` forwards to the new API.
- Keep `enableTimeToFullDisplayTracing` and `autoFinishAfter` in `SentryFlutterOptions`; inject into controller/engine.
- Side-by-side rollout: Do NOT remove or modify the existing TTID/TTFD code paths. Implement the new architecture in parallel (new files/classes). Opt-in via internal flag/new observer; removal of legacy code will be manual later.

#### Implementation tasks

1. Create module skeletons

   - Add `packages/flutter/lib/src/display/` with empty files: `display_timing_controller.dart`, `display_transaction_engine.dart`, `display_txn.dart`, `display_handles.dart`.
   - Add exports/wiring placeholders in `sentry_flutter.dart` or a dedicated barrel as needed.

2. Define state model (sealed)

   - In `display_txn.dart`: define sealed classes for `DisplayState` (`Idle`, `Active`, `Finished`, `Aborted`) and a `DisplayTxn` data holder (txn, spans, timestamps, timers, slot enum `root|route`).
   - Add small value objects (records) for `(start, end)` time pairs where helpful.

3. Implement the engine core

   - In `display_transaction_engine.dart`:
     - API: `start(slot, name, arguments, now)`, `finishTtid(slot, when)`, `finishTtfd(slot, when)`, `abort(slot, when)`, `snapshot()`.
     - Manage per-slot state, create/finish spans, add measurements, schedule/cancel TTFD timeout.
     - Guards with pattern matching; assert in debug, log+recover in release.
     - Inject dependencies: `Hub`, `SentryFlutterOptions`, `Clock`, timeout duration.

4. Tests: engine

   - Unit-test FSM transitions (legal/illegal), timeouts, pending TTFD-before-TTID, abort paths, idempotency.
   - Verify measurements/status semantics and snapshot diagnostics.

5. Add opaque handles

   - In `display_handles.dart`: implement `AppStartDisplayHandle` and `RouteDisplayHandle` bound to `(slot, spanId)`; methods delegate to controller; idempotent and safe after invalidation.

6. Implement the controller façade

   - In `display_timing_controller.dart`:
     - API: `startApp`, `startRoute`, `currentDisplay`, `abortCurrent`.
     - Policy: skip starts if tracing disabled or route ignored; map route name/args; invalidate old route handle; route to engine.
     - Keep a weak/current handle reference per slot.

7. Tests: controller

   - Validate handle invalidation, idempotency, and engine delegation.

8. Wire controller in options

   - In `SentryFlutterOptions`: add `late final displayTiming = DisplayTimingController(...)` with injected `Hub`, `Clock`, and `autoFinishAfter`.
   - Do NOT change behavior of existing `timeToDisplayTracker`; leave it intact. Add an internal experimental toggle (e.g., `experimentalUseDisplayTimingV2`, default false) to activate V2 paths without modifying legacy code.

9. Add `SentryNavigatorObserverV2` (side-by-side)

   - New observer uses the controller/engine:
     - On `didPush` (non-root): optionally `hub.generateNewTrace()`, call `controller.startRoute(name, args)` and capture the returned handle; bind transaction to scope if configured.
     - Immediately (synchronously in `didPush`) call `FrameCallbackHandler.addPostFrameCallback` with a callback that invokes `handle.endTtid(options.clock())` to ensure TTID captures the very first completed frame.
     - On `didPop`: `controller.abortCurrent(now)`.
     - On `didReplace`: `controller.startRoute(newName, args)` (engine auto-aborts previous).
     - Skip creating a new route transaction for the initial (root) route; the app-start transaction remains named `root /`.
     - Keep breadcrumbs and web-session logic as-is; no references to legacy trackers.
   - Do NOT modify the existing `SentryNavigatorObserver`. Provide documentation on opting into V2.

10. Tests: observer

- Verify route flows (push/pop/replace/ignore) and the synchronous post-frame TTID end.

11. Add Generic app-start integration V2 (side-by-side)

- Create a new class (e.g., `GenericAppStartIntegrationV2`) that uses the controller: `final h = controller.startApp(name: 'root /');` then `frame-callback → h.endTtid(now)`.
- Do NOT modify the existing integration.

12. Add Native app-start integration V2 (side-by-side)

- Create a new class (e.g., `NativeAppStartIntegrationV2`) that, on first frame timings, computes `appStartEnd`, calls `controller.startApp('root /').endTtid(appStartEnd)`.
- Reuse the existing `NativeAppStartHandler` to attach native spans to the V2 transaction; do not change the old integration.

13. Tests: app-start integrations

- Validate cold/warm start measurements and spans; verify deep-link scenarios and first-route behavior.

14. Back-compat and side-by-side wiring

- Keep public APIs (`SentryFlutter.currentDisplay()`, `SentryDisplayWidget`) untouched.
- Default behavior remains the legacy implementation. When the experimental toggle is enabled or when apps adopt the V2 observer/integrations, the same public APIs will be served by the new controller/engine under the hood.

15. Update example and docs

- Update any prose to reference `SentryFlutter.currentDisplay()` and navigator observer behavior.
- Mention `enableTimeToFullDisplayTracing` and default `autoFinishAfter`.
- Add documentation for Router 2.0/go_router: demonstrate passing `SentryNavigatorObserver` via `navigatorObservers` and how to opt into `SentryNavigatorObserverV2`.

16. Performance/robustness pass

- Ensure no extra allocations on hot path; timers are per-active-slot only.
- Confirm fire-and-forget finish paths catch/log in release and rethrow in test mode.

17. Cleanup

- Remove dead code, adjust imports, run lints, and ensure green CI.

18. Migration and deprecation

- If removing public classes, annotate with `@Deprecated` for one cycle (if policy requires), otherwise remove and note in CHANGELOG.
