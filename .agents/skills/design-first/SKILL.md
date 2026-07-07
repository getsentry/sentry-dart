---
name: design-first
description: Shape non-trivial work before writing it — decide the modules, the seams, and the public API surface up front. Use when starting a feature, adding an integration, changing a public barrel file, crossing a package or native-interop boundary, or deciding where a seam should go. Produces a design sketch to approve before implementation, then hands off to code-guidelines and test-guidelines.
---

Design the shape before writing the code. The pass ends in a **design sketch** the user approves; implementation does not start until it does. Aim for **deep modules** placed at clean **seams** — so callers get leverage, maintainers get locality, and tests get a surface to push against.

This is a design pass, not an implementation plan. Decide *what shape the code takes and why*; leave the line-level rules to code-guidelines and the test structure to test-guidelines.

## When to run

Run for work where the shape is a real decision:

- A new feature or a new `Integration`
- A change to a public barrel file (`lib/sentry.dart`, `lib/sentry_flutter.dart`) — it cascades to every downstream package and user
- Work that crosses a package boundary or the native-interop (JNI/FFI) boundary
- Any moment you are choosing where a seam goes, or how a module is shaped to be testable

Skip it — and say you are skipping it — for one-line fixes, localized bug fixes with obvious placement, and refactors that change no interface.

## Vocabulary

Use these terms exactly in the sketch and the discussion — consistent language is what makes the design legible across sessions. Don't substitute "component," "service," "layer," or "boundary."

- **Module** — anything with an interface and an implementation: a function, class, or package.
- **Interface** — everything a caller must know to use it correctly: the signature, plus invariants, ordering, error modes, and required config.
- **Deep module** — a lot of behavior behind a small interface. The goal. A **shallow** module has an interface nearly as complex as its implementation — avoid it.
- **Seam** — the place where you can swap behavior without editing in that place. Where a module's interface lives, and where a test double crosses.
- **Adapter** — a concrete thing satisfying an interface at a seam.

Two checks settle most design questions:

- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through — don't build it. If complexity reappears across N callers, it earns its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. If you need to test *past* the interface, the module is the wrong shape — and per test-guidelines, tests through a clean interface survive refactors.

## The design pass

### 1. Frame the change

State the behavior the change introduces, in the domain's own words. Name the package(s) it lands in. Read the relevant `AGENTS.md` (root, `packages/dart/`, `packages/flutter/`) for the area you're touching.

**Find the nearest well-shaped precedent and align to it.** The codebase has almost certainly solved something adjacent; locate its *best* current example and match it — or improve on it deliberately, noting why. The repo's own best-organized case is a stronger guide than any rule (e.g. follow `telemetry/span/` v2, not the v1 span scatter). This auto-updates as the codebase evolves.

**Decide file placement while the design is still cheap to change.** Group by feature, not by type. A processor or integration a feature owns lives in that feature's dir; a cross-cutting concern earns its own top-level concept dir. Cohesive subsystems already do this: `transport/`, `telemetry/span/`, and `native/` (the binding boundary to the platform SDKs; features call it rather than embed native code). Native interop is special for testing and memory, not for placement.

Treat these shapes as scatter, not precedent to grow:

- **Type-buckets** (`event_processor/`, `integrations/`) collect classes for sharing a base type. A bucket legitimately holds only its runner (`run_event_processors.dart`); the base contract belongs at `src/` root (`event_processor.dart`, beside `integration.dart`). The repo has not finished migrating older code, so do not read current loose placement as the target.
- **The loose `src/` root.** Core primitives (`hub.dart`, `scope.dart`, `sentry_client.dart`, the `sentry.dart` barrel) belong there; feature code does not. The v1 span/tracer files strewn across the root, `protocol/`, and `tracing/` are the counter-example to `telemetry/span/`.

### 2. Shape the modules

Decide the modules and where their seams go. Prefer fewer, deeper modules over many shallow ones. For each module, name its interface — not just the signature, but the invariants and error modes a caller must know. Run the deletion test on anything you suspect is a pass-through.

Decide where the code lives as part of shaping it — a **locality** call: co-locate what changes together so one change stays directory-local. The discriminator is **shared vs owned**:

- A cohesive subsystem owns its model, lifecycle, and pipeline as one **concept** — group it together, sized to the change (a big subsystem earns its own dir; a small addition matches the surrounding convention).
- Peel a piece into a **shared** module only when it has its own lifecycle *and* more than one consumer — the deletion test decides it (would extracting it concentrate complexity, or just move it?).
- **If you can't name the concern a piece serves, that's a smell** — it's doing two things, or belongs to a concept you haven't named yet. A cross-cutting concern (enrichment, exceptions) is still a concept with a home; a truly nameless one means the design is off.

Run a dependency ownership check for every new or renamed module:

- List each constructor dependency.
- Name the domain concern that dependency serves.
- If the module name cannot explain the dependency without "also", "legacy", "current code", or "for convenience", split the module or move orchestration up.
- If independent telemetry signals share source data, put that source data in an orchestrator or value object, not inside either signal emitter.

### 3. Design for testability

A seam exists so a test can cross it. For each module, name the seam its tests will cross and what fake injects there (test-guidelines builds these via `Fixture` + `getSut()`). Three rules make that possible:

- **Accept dependencies, don't create them.** A module that constructs its own transport or client can't be faked; one that receives it can.
- **Return results, don't bury side effects.** A function that returns a value is testable; one that only mutates shared state is not.
- **Keep the surface small.** Fewer methods and params mean less test setup.

Native interop is special: **JNI/FFI cannot be faked or mocked** (see `packages/flutter/AGENTS.md`). Put the seam at the Dart boundary *above* native so the logic is unit-testable, and plan an integration test for the native path itself.

### 4. Check the SDK constraints

Resolve these before sketching — each has a canonical home; consult it rather than guessing:

- **Public API surface.** Does this add or change exports in a barrel file? Keep new types in `src/` unless they're meant for SDK users. See `packages/dart/AGENTS.md`.
- **Public type extension.** For every new public type, decide whether it is `final`, `base`, `interface`, or `sealed`; code-guidelines has the mechanics.
- **Data collection and privacy.** State the data collected or propagated, whether it can contain PII, and which option or condition gates it. If there is no new data, say `none`.
- **Breaking changes.** State whether the change is breaking; if so, decide the migration path before implementation.
- **Integration shape.** If the feature is an `Integration`, it implements `call()`/`close()`, gates on its prerequisites early, and stays order-independent. See code-guidelines.
- **Package boundary.** Core behavior belongs in `packages/dart/`; integration-specific behavior in its own package. A new dependency in core cascades everywhere.

### 5. Write the design sketch and get approval

Write a short sketch — prose or bullets, not code — and present it. **Do not start implementing until the user approves it.**

The sketch is complete when it states, for the change:

- [ ] Each module, its interface, and whether it's new or modified
- [ ] File placement for each new or moved module, including the precedent it follows
- [ ] Dependency ownership: every dependency belongs to the module's named concern
- [ ] Signal independence: adjacent telemetry signals sharing source data are orchestrated above their emitters
- [ ] The seam each module's tests cross, and the fake that injects there (or "integration test" where native)
- [ ] The public-API-surface impact (barrel-file exports added/changed, or "none")
- [ ] Public type modifiers, data/PII gating, and breaking-change status when relevant
- [ ] One alternative shape you considered and why you rejected it

If the solution space is wide and the best interface isn't obvious, design it twice before sketching — see [references/design-it-twice.md](references/design-it-twice.md).

### 6. Hand off

On approval, implement under code-guidelines, and write tests under test-guidelines at the seams this sketch named.
