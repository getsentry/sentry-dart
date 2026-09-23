# sentry

Core Dart SDK — foundation for all other packages in this monorepo.

## Public API Surface

`lib/sentry.dart` is the public barrel file. Changes here affect all downstream packages and users.

- Every new public type must be exported from `lib/sentry.dart`
- Integration packages (`sentry_flutter`, `sentry_dio`, etc.) depend on this package — regressions here cascade everywhere
- Do not export internal helpers from `lib/sentry.dart` only for sibling packages; prefer direct `src/` imports within this monorepo when the API is not meant for SDK users
- Avoid exporting extensions on common Dart/core types like `Iterable`, `String`, or `Map`; they affect user extension resolution and can conflict with `dart:*` or popular packages
- If a helper truly must be public, prefer an explicit named API over extension methods for common types

## Key Directories

- `lib/src/protocol/` — Shared event and context representations
- `lib/src/envelope/` — Envelope payloads and serialization
- `lib/src/transport/` — Delivery, queuing, and rate limiting
- `lib/src/telemetry/span/` — Transaction and streaming spans, shared sampling, propagation, and instrumentation
- `lib/src/telemetry/` — Logs, metrics, spans, and shared processing pipelines
- `lib/src/exception/` — Exception identification, extraction, and processing
- `lib/src/enrichment/` — Event enrichment and runtime information
- `lib/src/http_client/` — HTTP client instrumentation
- `lib/src/client_reports/` — Client-side outcome reporting
- `lib/src/utils/` — Shared internal utilities including `SentryInternalLogger`

Feature integrations and processors live with their owning feature. Tests mirror feature directories.
