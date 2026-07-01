---
name: code-guidelines
description: Enforce Sentry Dart/Flutter SDK code guidelines for implementation, refactoring, and review. Use when implementing features, adding new functionality, refactoring code, reviewing code, designing APIs, modifying public API surface, handling breaking changes, deprecating APIs, writing integrations, or making architecture decisions in any package in this Melos monorepo.
---

Apply these guidelines to all new and modified code across every package in this monorepo. Existing code may not follow these conventions — do not refactor it unless asked.

Use only language features available in the Dart/Flutter versions specified in `AGENTS.md`.

For non-trivial work — a new feature or integration, a public barrel-file change, or a cross-package/native-interop change — load the **design-first** skill to shape the modules and seams before writing code. When writing or modifying tests as part of implementation, also load the **test-guidelines** skill.

## SDK Development Rules

### Integrations

Encapsulate SDK features as `Integration` classes that implement `call()` and `close()`:

- Check feature flags and prerequisites early, log and return if disabled
- Mark the integration as active for usage tracking — see **Usage Tracking** below
- Clean up resources in `close()` if needed
- See `packages/flutter/lib/src/integrations/` for examples
- Integrations should be order-independent; if yours requires running before/after another, reconsider the design

### Usage Tracking

Record which integrations and features an app actually uses, so usage can be tracked internally. This metadata lives on `options.sdk` and is serialized onto events as `sdk.integrations` / `sdk.features`.

- **`options.sdk.addIntegration('IntegrationName')`** — mark an integration as active. Call it from the integration's `call()`. Do not confuse it with `options.addIntegration(integration)`, which *registers an integration to run* — `options.sdk.addIntegration` only attaches the name as metadata.
- **`options.sdk.addFeature(SentryFeatures.x)`** — mark a feature as used, gated on whether it is actually configured (e.g. a `beforeSend*` callback is set, a privacy option is enabled).
- Use named constants from `SentryFeatures` (`packages/dart/lib/src/constants.dart`, `@internal`) — never inline string literals — so the analytics vocabulary stays consistent. Add a constant there when introducing a new feature.
- Both calls dedupe, so calling them more than once is safe.
- Canonical example: `TrackBeforeSendUsageIntegration` (`packages/dart/lib/src/track_before_send_usage_integration.dart`).

### Logging

Use `internalLogger` for all diagnostic logging. `options.log` is deprecated — migrate any `options.log` calls you encounter to `internalLogger`.

Each package must have its own `internalLogger` instance. If one doesn't exist, create `lib/src/internal_logger.dart`:

```dart
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Logger for the Sentry <Package> SDK.
@internal
const internalLogger = SentryInternalLogger('sentry_<package>');
```

**Log levels:**

| Level | Use for |
|-------|---------|
| `debug` | Routine lifecycle events, configuration confirmations, verbose tracing |
| `info` | Notable but expected events (parsing results, fallback paths taken) |
| `warning` | Recoverable problems (rate limits hit, missing optional config, degraded functionality) |
| `error` | Failures that affect SDK behavior (transport errors, parsing failures) |
| `fatal` | Unrecoverable errors requiring SDK shutdown |

**Lazy evaluation** — use a closure when the message involves expensive computation:

```dart
internalLogger.debug(() => 'Envelope size: ${envelope.computeSize()}');
```

**Logs are debug-only** — all logging is tree-shaken in release builds via `RuntimeChecker.kDebugMode`.

### Privacy

- Never collect Personally Identifiable Information (PII) without checking `options.sendDefaultPii`
- Flag any changes that could leak PII for review

### Breaking Changes

- Signal breaking changes clearly (API removals, behavior changes, renamed options)
- Prefer deprecation with migration path over immediate removal

### Native Code (JNI/FFI)

- Release all native memory (JNI local refs, malloc allocations)
- Handle native exceptions gracefully—don't crash the host app

### File Organization

`lib/src/` mixes two organizing axes: **by-kind layer dirs** (`protocol/`, `event_processor/`, `integrations/`, `native/`, `transport/`) and **by-feature concept dirs** (`replay/`, `frames_tracking/`, `navigation/`, `tracing/`, `telemetry/span/`). The repo facts:

- **Group by concept, not by kind.** A feature-owned processor/integration goes with its feature (a replay processor in `replay/`). A cross-cutting one (enrichment, exceptions, dedup) is still a concept and earns its own concept dir too — core's `enricher/` and `exception/`. `event_processor/` / `integrations/` are by-kind names; they justify a directory only for the **shared machinery** (the runner `run_event_processors.dart`, the base contracts), not as a bucket where concepts land because they share a type. Whether the cross-cutting concept dirs sit top-level or nest under that machinery is a locality call (see design-first). Feature-specific processors sitting loose in the buckets (e.g. `replay_event_processor`, `screenshot_event_processor`) are scatter to steer away from, like the loose tier. (The `Integration` interface itself sits at the `src/` root, e.g. `integration.dart`.)
- **`native/` is the standing seam exception** — native interop has its own rules (memory, can't be faked; see `packages/flutter/AGENTS.md`), so native adapters group by that seam even when they belong to a concept.
- The top of `src/` mixes **core primitives** (`hub.dart`, `scope.dart`, `sentry_client.dart`, the `sentry.dart` barrel) with **legacy scatter** (e.g. the v1 span/tracer files). Don't add new feature code to that loose tier — put it in a concept or layer dir.
- The example to match is `telemetry/span/` (v2 span: a cohesive subsystem in one dir), not the v1 span scattered across `protocol/`, `tracing/`, and loose root files.

*Where* a given piece goes is a locality judgment — see **design-first** (Shape the modules).

## Modern Dart

Prefer modern Dart (3.5+) where it improves clarity — sealed classes for exhaustive matching, records for multi-value returns, pattern matching and switch expressions, extension types for zero-cost wrappers, enhanced enums, and class modifiers (`final` / `base` / `interface`). Don't force them where plain code reads better.

## API & Dart Style

Shape the public surface deliberately — see **design-first** for module shape. These habits matter more in an SDK than in app code, and several are easy to get wrong:

- **Private by default.** Keep declarations private; widen to public only when a type is genuinely part of the SDK's API. Every public symbol is a maintenance burden and a breaking-change liability — see `packages/dart/AGENTS.md` on the barrel-file cascade.
- **Control extension with class modifiers.** Use `final` / `base` / `interface` / `sealed` to declare whether a public class may be extended or implemented — without them every public class is implicitly both, and you can't evolve it without breaking consumers.
- **No public `late final` field without an initializer.** It silently defines a public *setter*, leaking API surface — use a normal field or an explicit getter instead.
- **Prefer a function to a one-member abstract class**, and avoid classes of only static members.
- **Keep imports inside `lib`.** Never let an import cross the `lib` boundary (`../lib/...`, or into another package's `src/`) — relative imports that escape `lib` create duplicate library instances Dart treats as unrelated.
- **Re-raise with `rethrow`, never `throw e`.** `throw e` resets the stack trace to the rethrow site; `rethrow` preserves the origin — and stack-trace fidelity is the product.

For everything else — naming, asynchrony, nullability, parameters, equality — follow **Effective Dart**; a frontier model and `dart analyze` already apply most of it, so it isn't restated here. The full checklist (and the standard the `review` skill cites) is in [references/effective-dart.md](references/effective-dart.md).

## Documentation Comments

Prefer self-documenting code — clear names and structure so comments become unnecessary.

**Comment when:**

- **Public APIs** — document for users who can't see the implementation.
- **Non-obvious *why*** — reasoning not clear from the code (workarounds, edge cases, constraints).

**Don't comment when:**

- **Obvious behavior** — don't describe what the code plainly does.
- **Inline play-by-play** — don't narrate every step of a method.

**`dart doc` gotchas** (tooling behavior, not taste):

- Document a getter *or* its setter, never both — `dart doc` merges the pair and discards the setter's comment.
- The first sentence becomes the summary in API listings — keep it standalone in its own paragraph.
- Put doc comments *before* annotations (`@override`, `@internal`); placed after, `dart doc` won't associate them with the declaration.

Remaining doc-comment style (`///`, `[bracket]` references) is standard Effective Dart — see [references/effective-dart.md](references/effective-dart.md).
