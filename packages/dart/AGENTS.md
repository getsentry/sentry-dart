# sentry

Core Dart SDK — foundation for all other packages in this monorepo.

## Public API Surface

`lib/sentry.dart` is the public barrel file. Changes here affect all downstream packages and users.

- Every new public type must be exported from `lib/sentry.dart`
- Integration packages (`sentry_flutter`, `sentry_dio`, etc.) depend on this package — regressions here cascade everywhere

## Key Directories

- `lib/src/protocol/` — Sentry protocol types (events, breadcrumbs, spans, envelopes)
- `lib/src/transport/` — HTTP transport, rate limiting, envelope serialization
- `lib/src/tracing/` — Distributed tracing, span creation, sampling
- `lib/src/telemetry/` — Metrics, logs, span v2 and processing pipelines
- `lib/src/event_processor/` — Event enrichment and filtering
- `lib/src/http_client/` — HTTP client instrumentation
- `lib/src/client_reports/` — Client-side outcome reporting
- `lib/src/utils/` — Internal utilities including `SentryInternalLogger`
