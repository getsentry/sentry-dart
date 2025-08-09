# PR Review Rules (packages/dart)

Reviewer-focused checks for the core `sentry` (Dart-only) package. Keep comments specific and fix-oriented. Prefer small suggestions over walls of text.

## Platform Boundaries

- Flag: Imports from Flutter (`package:flutter/*`) or `dart:ui`
  - Why: breaks pure Dart/VM/Web consumers
  - Fix: remove Flutter dependencies; keep core platform-agnostic
- Flag: Unconditional `dart:io` imports in code paths used on Web
  - Why: breaks Web builds
  - Fix: use conditional imports/exports (io vs html) and guard usage

## Transport & Rate Limiting

- Flag: Ignoring `X-Sentry-Rate-Limits` or `Retry-After`
  - Why: server strain; dropped events later
  - Fix: cache per-category TTL and skip sends until expiry; respect `Retry-After`
- Flag: Unbounded retries or no backoff/jitter
  - Why: tight retry loops under outages
  - Fix: bounded exponential backoff with jitter and max attempts
- Flag: Synchronous file/network I/O inside transport
  - Why: blocks event loop; harms performance even outside Flutter
  - Fix: use async I/O and batching; avoid blocking APIs

## Serialization & Protocol Stability

- Flag: JSON/envelope schema changes that rename keys or remove fields
  - Why: breaks server parsing and older SDK interoperability
  - Fix: add new optional fields with defaults; keep old keys readable; deprecate before removal
- Flag: Deserializers that throw on unknown/missing fields
  - Why: forward/backward incompatibility
  - Fix: tolerate unknown fields; provide sensible defaults
- Flag: Large unbounded strings/collections added to events
  - Why: oversized envelopes; higher latency
  - Fix: truncate long strings; cap list/map sizes; summarize data

## Sampling & Tracing Core Rules

- Flag: `tracesSampler` not taking precedence over `tracesSampleRate`
  - Why: incorrect sampling decisions
  - Fix: evaluate `tracesSampler` first; clamp rates to [0.0, 1.0]
- Flag: Creating performance spans when the transaction is not sampled
  - Why: wasted work and noisy data
  - Fix: short-circuit span creation when parent transaction is unsampled (errors still allowed)

## Event Processing

- Flag: Event processors that throw or perform heavy I/O
  - Why: dropped events; latency
  - Fix: wrap in try/catch and return original event on failure; keep processors fast/pure
- Flag: Processors that mutate shared state or re-enter capture paths
  - Why: recursion/loops; hard-to-debug side effects
  - Fix: avoid calling `capture*` from processors; keep them side-effect-free

## Concurrency & Isolates

- Flag: Assuming a single global Hub across isolates
  - Why: missed breadcrumbs/context in spawned isolates
  - Fix: bind a client/hub in new isolates (`Sentry.bindClient`) or pass hub explicitly
- Flag: Relying on mutable global singletons rather than Hub/Scope
  - Why: cross-request leakage
  - Fix: use `Hub`/`Scope` APIs; avoid global mutable state for context

## Header Propagation (Core helpers)

- Flag: Overwriting existing `baggage` header instead of merging
  - Why: loses upstream vendor entries
  - Fix: merge Sentry items into existing baggage; keep within size limits
- Flag: Invalid `sentry-trace` formatting
  - Why: broken trace linking
  - Fix: ensure `<traceId>-<spanId>-<sampled?>` format and propagate consistently

## Timekeeping & Durations

- Flag: Using `DateTime.now()` diffs for durations
  - Why: clock skew; non-monotonic
  - Fix: prefer `Stopwatch` for measuring durations; use UTC timestamps for event time

## Handy one-liners

- Conditional import example: `import 'client_io.dart' if (dart.library.html) 'client_web.dart';`
- Safe sampler clamp: `final r = (rate ?? 0).clamp(0.0, 1.0);`
