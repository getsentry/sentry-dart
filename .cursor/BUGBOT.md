# PR Review Guidelines for Cursor Bot

Reviewer-focused checks for Sentry Dart/Flutter SDK PRs. Keep comments specific and fix-oriented. Prefer small suggestions over walls of text. If you find anything to flag, mention that you flagged this in the review because it was mentioned in this rules file. Do not flag the issues below if they appear only in tests.

## Critical Issues to Flag

### Security & Privacy

- Flag: Secrets/DSNs/tokens added to code or config
  - Why: credential leakage
  - Fix: use placeholders or env/CI injection; never commit real secrets
- Flag: PII added to events/breadcrumbs/tags/extras (emails, tokens, device IDs)
  - Why: privacy/legal risk
  - Fix: redact via `beforeSend`/`beforeBreadcrumb`

### Public API & Stability

- Flag: Public API changes without deprecation/migration notes
  - Why: breaks downstream users
  - Fix: deprecate first; provide migration guidance
- Flag: Removal of publicly exported functions/classes/types
  - Why: breaking change
  - Fix: keep exported symbols or add deprecations

## Architecture & Options

- Flag: Sync I/O on UI isolate
  - Why: jank/hangs
  - Fix: async/non-blocking I/O;

## Performance & Tracing

- Flag: Spans/transactions started but not finished
  - Why: memory/time skew
  - Fix: `try { … } finally { span?.finish(); }`
- Flag: Double instrumentation of HTTP
  - Why: duplicate spans/breadcrumbs
  - Fix: avoid combining Dio interceptor with `SentryHttpClient` (pick one)

## Auto Instrumentation and Sentry conventions

- Flag: Missing span op or origin on auto-instrumented spans
  - Why: weak classification and trace analysis
  - Fix: ensure spans include op (`sentry.op`) and origin (`sentry.origin`) when starting
- Flag: Missing origin on auto-instrumented logs
  - Why: weak classification and log analysis
  - Fix: ensure all logs triggered from auto instrumentation include origin (`sentry.origin`)
- Flag: High-cardinality or sensitive span descriptions (IDs, tokens, query strings)
  - Why: privacy risk; noisy data
  - Fix: use stable, sanitized descriptions (route names, table names)
- Prefer canonical ops where applicable: `http.client`, `db.query`, `file.read`, `navigation`, `ui.load`

## Performance Issues

- Flag: Breadcrumb/tag flood (logging every iteration/request)
  - Why: high overhead, storage noise
  - Fix: throttle/summarize; cap with `maxBreadcrumbs`; use `beforeBreadcrumb` to drop noisy entries
- Flag: High-cardinality tags/extras (UUIDs, timestamps, raw IDs)
  - Why: poor aggregation; increased storage
  - Fix: bucket/normalize (e.g., `user_tier=premium`) or redact
- Flag: Large events/attachments (images, payload dumps)
  - Why: big envelopes; slower transport
  - Fix: avoid attachments by default; truncate strings; record counts/sizes instead of bodies
- Flag: Per-request interceptor/listener setup
  - Why: repeated allocation overhead
  - Fix: register interceptors once at client init
- Flag: Creating spans in tight loops or per-frame callbacks
  - Why: overhead and memory churn
  - Fix: sample or instrument at a coarser granularity
- Flag: Heavy work in `build()`/frame callbacks
  - Why: jank and dropped frames
  - Fix: move to `initState`/effects or background; memoize; use `const` widgets
- Flag: Un-cancelled `Timer`/`StreamSubscription`/controller
  - Why: leaks and unexpected callbacks
  - Fix: store and cancel/dispose in lifecycle
- Flag: Repeated JSON encode/decode or large map copies in hot paths
  - Why: CPU/memory overhead
  - Fix: cache parsed forms; avoid full spreads on large maps
- Flag: Using isolates/`compute` for trivial work or non-transferable objects
  - Why: overhead outweighs benefit; runtime errors
  - Fix: offload only CPU-bound, transferable workloads
- Flag: Expensive `RegExp` in hot paths
  - Why: CPU spikes
  - Fix: precompile/simplify patterns; avoid catastrophic quantifiers
