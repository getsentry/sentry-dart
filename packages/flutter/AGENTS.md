# sentry_flutter

Flutter SDK with native integrations across all platforms.

## Public API Surface

`lib/sentry_flutter.dart` is the public barrel file. Changes here affect all downstream packages and users.

- Every new public type must be exported from `lib/sentry_flutter.dart`

## Native Code

| Platform | Language | Path |
|----------|----------|------|
| Android | Kotlin | `android/src/main/kotlin/io/sentry/flutter/` |
| iOS/macOS | Swift/ObjC | `darwin/sentry_flutter/` |
| Linux | C++ | `linux/` |
| Windows | C++ | `windows/` |

- JNI bindings use `package:jni`; FFI bindings use `dart:ffi`
- JNI should pass primitives directly. Small, controlled `Map`/`List` payloads may use direct conversion; arbitrary or large payloads should cross as UTF-8 JSON bytes and deserialize on Kotlin/Java.
- JNI and FFI can currently only be tested through integration test since they cannot be injected / mocked or faked.

## Key Directories

- `lib/src/native/` — Native SDK interop, generated bindings, and platform adapters
- `lib/src/web/` — JavaScript SDK interop and script loading
- `lib/src/replay/` — Replay lifecycle, scheduling, and configuration
- `lib/src/screenshot/` — Event screenshot integration and processing
- `lib/src/screen_capture/` — Shared screenshot/replay capture, masking, and capture-widget lifecycle
- `lib/src/bindings/` — Shared Flutter bindings, frame callbacks, and lifecycle support
- `lib/src/frames_tracking/` — Frame metrics collection
- `lib/src/navigation/` — Route observation and display timing
- `lib/src/exception/` — Flutter/platform exception handling, including JVM parsing
- `lib/src/enrichment/` — Context, release, feature-flag, and thread enrichment
- `example/integration_test/` — Native and end-to-end tests

Feature integrations and processors live with their owning feature. Tests mirror feature directories.
