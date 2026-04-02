# sentry_flutter

Flutter SDK with native integrations across all platforms.

## Public API Surface

`lib/sentry_flutter.dart` is the public barrel file. Changes here affect all downstream packages and users.

- Every new public type must be exported from `lib/sentry_flutter.dart`

## Native Code

| Platform | Language | Path |
|----------|----------|------|
| Android | Kotlin | `android/src/main/kotlin/io/sentry/flutter/` |
| iOS/macOS | Swift/ObjC | `ios/sentry_flutter/` |
| Linux | C++ | `linux/` |
| Windows | C++ | `windows/` |

- Release all native memory (JNI local refs, malloc allocations)
- Handle native exceptions gracefully — never crash the host app
- JNI bindings use `package:jni`; FFI bindings use `dart:ffi`
- JNI and FFI can currently only be tested through integration test since they cannot be injected / mocked or faked.


## Key Directories

- `lib/src/integrations/` — Integration implementations (reference for new integrations)
- `lib/src/native/` — Native interop layer
- `lib/src/replay/` — Session replay
- `lib/src/navigation/` — Route observer and navigation tracing
- `example` — Flutter Example App
- `example/integration_test` — Integration test suite
