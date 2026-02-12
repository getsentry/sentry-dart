# PR Review Guidelines for Cursor Bot (Root)

**Scope & intent**

- High-level review guidance for the entire monorepo.
- Optimize for **signal over noise**: only comment when there’s material correctness, security/privacy, performance, or API-quality impact.
- If you find anything to flag, mention that you flagged this in the review because it was mentioned in this rules file.
- Do not flag the issues below if they appear only in tests.

**Reviewer style**

- Be concise. Quote exact lines/spans and propose a minimal fix (tiny diff/code block).
- If something is subjective, ask a brief question rather than asserting.
- Prefer principles over nitpicks; avoid noisy style-only comments that don’t impact behavior.

---

## 0) Critical Issues to Flag

> Use a clear prefix like **CRITICAL:** in the review comment title.

### A. Security & Privacy

- **Secrets / credentials exposure**: Keys, tokens, DSNs, endpoints, or auth data in code, logs, tests, configs, or example apps.
- **PII handling**: New code that logs or sends user-identifiable data without clear intent and controls. These must be gated behind the `sendDefaultPii` flag.
- **Unsafe logging**: Request/response bodies, full URLs with query secrets, file paths or device identifiers logged by default.
- **File/attachments**: Large or sensitive payloads attached by default; lack of size limits or backoff.
- **Debug code shipped**: Diagnostics, sampling overrides, verbose logging, or feature flags accidentally enabled in production defaults.

### B. Public API & Stability

- **Breaking changes**: Signature/behavior changes, renamed/removed symbols, altered nullability/defaults, or event/telemetry shape changes **without** deprecation/migration notes.
- **Behavioral compatibility**: Silent changes to defaults, sampling, or feature toggles that affect existing apps.

### C. Dependency Updates

- **Native SDK updates**: For PRs prefixed with `chore(deps):` updating native SDKs (e.g., `chore(deps): update Android SDK to v8.32.0`, `chore(deps): update Cocoa SDK to v9.0.0`):
  - Read the PR description which should contain the changelog.
  - Review mentioned changes for potential compatibility issues in the current codebase.
  - Flag breaking API changes, deprecated features being removed, new requirements, or behavioral changes that could affect existing integrations.
  - Check if version bumps require corresponding changes in native bridge code, method channels, or platform-specific implementations.

---

## 1) General Software Quality

**Clarity & simplicity**

- Prefer straightforward control flow, early returns, and focused functions.
- Descriptive names; avoid unnecessary abbreviations.
- Keep public APIs minimal and intentional.

**Correctness & safety**

- Add/update tests with behavioral changes and bug fixes.
- Handle error paths explicitly.
- Avoid global mutable state; prefer immutability and clear ownership.

**DRY & cohesion**

- Remove duplication where it reduces complexity; avoid over-abstraction.
- Keep modules cohesive; avoid reaching across layers for convenience.

**Performance (pragmatic)**

- Prefer linear-time approaches; avoid unnecessary allocations/copies.
- Don’t micro-optimize prematurely—call out obvious hotspots or regressions.
- Use streaming/iterables over building large intermediates when feasible.

---

## 2) Dart-Specific

**Idioms & language features**

- Avoid `!` (null assertion) on nullable targets; use guards or null-aware operators.
- Follow Effective Dart style and documentation; document public symbols.
- Consider modern Dart 3.x features (e.g., sealed classes) when they clarify the model.

**Safety & async**

- Avoid unawaited futures unless intentional and documented.
- Cancel `StreamSubscription`s and dispose resources deterministically.

**Concurrency & isolates**

- For CPU-bound work with simple inputs/outputs, consider offloading to an **isolate**; avoid complex object graphs needing heavy serialization.

**Tree-shakeability**

- Avoid patterns that defeat tree shaking
- Use const constructors/values where it makes sense to enable constant folding/canonicalization.
- Instantiate optional features/integrations inside guarded branches (e.g., if (options.enableX) { ... }).
- Prefer typed factories over dynamic/string lookups

---

## 3) SDK-Specific (high-level)

**Tracing & spans**

- Any span started must be **closed**.
- For _automated_ instrumented spans, always set:
    - `sentry.origin`
    - `sentry.op` using a standard operation where applicable (see [Sentry’s list of standard ops](https://develop.sentry.dev/sdk/telemetry/traces/span-operations/)).

**Structured logs**

- For _automated_ instrumented structured logs, always set `sentry.origin`.

**Initialization & error paths**

- Wrap dangerous or failure-prone paths (especially during `Sentry`/`SentryFlutter` init) in `try/catch`, add actionable context, and ensure fallbacks keep the app usable.

---

## Quick reviewer checklist

- [ ] **CRITICAL:** No secrets/PII/logging risks introduced; safe defaults preserved.
- [ ] **CRITICAL:** Public API/telemetry stability maintained or properly deprecated with docs.
- [ ] **CRITICAL:** For dependency updates (`chore(deps):`), changelog reviewed for breaking changes or compatibility issues.
- [ ] Spans started are always closed; automated spans/logs include `sentry.origin` (+ valid `sentry.op` for spans).
- [ ] Dangerous init paths guarded; app remains usable on failure.
- [ ] No `!` on nullable targets; async gaps guarded; resources disposed.
- [ ] Tests/docs/CHANGELOG updated for behavior changes.