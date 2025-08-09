### Project review guidelines

Concise checks for `sentry_flutter` PRs. Prefer specific, fix-oriented comments.

### Architecture

- Initialize once via `SentryFlutter.init((o) { ... }, appRunner: () => runApp(...))`. Flag multiple inits or app-level hubs recreated in widgets.
- Hooking errors: if overriding `FlutterError.onError` or `PlatformDispatcher.instance.onError`, chain to Sentry (`Sentry.captureException`) and preserve existing handlers.
- Use a single `SentryNavigatorObserver` at the app root. Duplicates cause double spans and breadcrumbs.
- Don’t access `DefaultBinaryMessenger`/platform channels from background isolates.
- Avoid setting `Sentry.options` in `build()`; configure during init or at startup.

### Security & privacy

- Redact auth/session/user PII in `beforeSend`/`beforeBreadcrumb`.
- Don’t record full route parameters with secrets. Prefer sanitized route names.
- Screenshots/attachments: ensure opt-in and policy compliance; avoid capturing sensitive screens.

### Performance & tracing

- App start/route spans: ensure spans are finished, especially on navigation errors or cancellation.
- Avoid double-instrumentation with both `SentryNavigatorObserver` and manual route spans; choose one strategy per route.
- Network layers (Dio/HttpClient): ensure only one integration is active to prevent duplicate spans.
- Prefer `tracesSampler` over `tracesSampleRate` for dynamic sampling. Warn on `1.0` in production diffs.

### Platform specifics

- Android: keep R8/ProGuard rules for Sentry classes; ensure mapping upload is present in release workflows.
- iOS: dSYM uploads must be part of release workflows; keep DWARF-with-dSYM; avoid bitcode settings that break symbolication.
- Web: ensure source maps are emitted and uploaded; stack frames mapped; guard for differing stack formats.

### Common issues (with fixes)

- Multiple `SentryNavigatorObserver` instances.
  - Fix: provide a single instance at `MaterialApp.navigatorObservers`.
- Overriding `FlutterError.onError` without chaining.
  - Fix: call previous handler and `Sentry.captureException(e, stackTrace: st)`.
- Spans left unfinished on navigation or async cancellation.
  - Fix: wrap with `try { … } finally { span?.finish(); }`.
- PII in breadcrumbs/tags/extras.
  - Fix: redact in `options.beforeSend`/`beforeBreadcrumb`.

### Handy one-liners

- Route span finish: `try { /* push */ } finally { span?.finish(); }`
- Chain error handler: `final prev = FlutterError.onError; FlutterError.onError = (d) { prev?.call(d); Sentry.captureException(d.exception, stackTrace: d.stack); };`
