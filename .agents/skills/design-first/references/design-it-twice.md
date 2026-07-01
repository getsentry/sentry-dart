# Design It Twice

When the best interface for a module isn't obvious, design it more than one way before committing. Your first idea is rarely the best (Ousterhout). Uses the vocabulary from [SKILL.md](../SKILL.md) — **module**, **interface**, **seam**, **adapter**, deep vs shallow.

Two ways to run it, by how wide the space is.

## Inline — sketch two or three interfaces yourself

For most cases, write the contrasting interfaces in the sketch itself:

1. **Frame the constraints** the interface must satisfy — invariants, the callers it serves, the seam its tests cross, the dependencies behind it.
2. **Write 2–3 genuinely different interfaces** under those constraints. Make them diverge, not rephrase:
   - **Minimal** — 1–3 entry points, maximum leverage each.
   - **Flexible** — supports more callers and extension.
   - **Common-case-first** — the default call is trivial; rarer needs cost more.
3. **Compare on depth, locality, and seam placement**, then recommend one. Propose a hybrid if pieces combine well. Be opinionated.

## Parallel sub-agents — for genuinely large surfaces

When the surface is large enough that exploring it inline would crowd the design pass, spawn the explorations concurrently:

- Spawn 3+ agents with the `Agent` tool, each given one of the constraints above plus a technical brief (file paths, coupling, what sits behind the seam, the dependency it injects).
- Each returns: the interface (types, methods, params, invariants, error modes), a caller usage example, what the implementation hides, the fake its tests inject, and trade-offs.
- Present them sequentially, compare in prose on **depth** / **locality** / **seam placement**, and give a recommendation.

## Dependencies, for this SDK

Classify what a module depends on — it decides how the module is tested across its seam:

- **In-process** — pure computation, in-memory state. No adapter; test through the interface directly.
- **Injected Dart dependency** — transport, HTTP client, clock, a third-party Dart client (e.g. a DB driver in an integration package). Inject it as an interface; tests pass a fake (test-guidelines' `Fixture`).
- **Native (JNI/FFI)** — cannot be faked. Put the seam at the Dart boundary above native so the logic is unit-testable; cover the native path with an integration test (see `packages/flutter/AGENTS.md`).

One adapter means a hypothetical seam; two means a real one (typically production + test). Don't introduce a seam unless something actually varies across it — a single-adapter seam is just indirection.
