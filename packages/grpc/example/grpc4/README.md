# grpc4 — sentry_grpc Flutter example

Flutter example app demonstrating `SentryGrpcInterceptor` with `SentryFlutter`.

## What it shows

- `SentryFlutter.init` + `SentryWidget` for Flutter-native SDK setup
- `SentryGrpcInterceptor` attached to a `ClientChannel` targeting `grpcb.in:9001`
- `captureFailedRequests: true` on the interceptor

## Buttons

| Button | Endpoint | Purpose |
|--------|----------|---------|
| Good Request | `rsa4096.badssl.com` (HTTPS) | Successful HTTP request |
| Bad Request | `expired.badssl.com` (HTTPS) | SSL error — captured as exception |
| gRPC Request | `GRPCBin/Empty` | Successful unary RPC; creates a span |
| DummyUnary | `GRPCBin/DummyUnary` | Sends a string, echoes it back |
| RandomError | `GRPCBin/RandomError` | Randomly fails; tests error span + capture |

## Run

```sh
cd packages/grpc/example/grpc4
flutter run
```

Set your DSN in `lib/app_config.dart` before running.
