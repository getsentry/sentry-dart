# grpc5 — sentry_grpc Dart example

Flutter app demonstrating `SentryGrpcInterceptor` with the plain Dart `Sentry.init` (no Flutter-specific SDK).

## What it shows

- `Sentry.init` (not `SentryFlutter`) — suitable for pure Dart or minimal-Flutter setups
- `SentryGrpcInterceptor` with `captureFailedRequests: true`
- Request header capture in spans — the **WithHeaders** call passes `meat: vegetable` custom metadata, visible as `http.request.header.meat` in the span data
- Typed proto serialization via a hand-written `DummyMessage` class (field-level encode/decode)

## Buttons

| Button | Endpoint | Purpose |
|--------|----------|---------|
| Good Request | `rsa4096.badssl.com` (HTTPS) | Successful HTTP request |
| Bad Request | `expired.badssl.com` (HTTPS) | SSL error — captured as exception |
| gRPC Request | `GRPCBin/Empty` | Successful unary RPC; creates a span |
| DummyUnary | `GRPCBin/DummyUnary` | Typed `DummyMessage` round-trip |
| RandomError | `GRPCBin/RandomError` | Randomly fails; tests error span + capture |
| WithHeaders | `GRPCBin/DummyUnary` + metadata | Verifies header capture in span data |

## Differences from grpc4

| | grpc4 | grpc5 |
|-|-------|-------|
| SDK init | `SentryFlutter.init` + `SentryWidget` | `Sentry.init` |
| Proto encoding | Inline byte helpers | Typed `DummyMessage` class |
| WithHeaders button | No | Yes |

## Run

```sh
cd packages/grpc/example/grpc5
flutter run
```

Set your DSN in `lib/app_config.dart` before running.
