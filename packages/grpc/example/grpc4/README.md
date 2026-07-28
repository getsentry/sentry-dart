# grpc4 — sentry_grpc Dart example

Dart CLI example demonstrating `SentryGrpcInterceptor` with grpc 4.x.

## What it shows

- `Sentry.init` with `tracesSampleRate` and `captureFailedRequests`
- `SentryGrpcInterceptor` attached to a `ClientChannel` targeting `grpcb.in:9001`
- Manual transaction wrapping around each RPC call

## Calls

| Call | Endpoint | Purpose |
|------|----------|---------|
| Empty | `GRPCBin/Empty` | Successful unary RPC; creates a span |
| DummyUnary | `GRPCBin/DummyUnary` | Sends a string, echoes it back (hand-encoded proto) |
| RandomError | `GRPCBin/RandomError` | Randomly fails; tests error span + capture |

## Differences from grpc5

| | grpc4 | grpc5 |
|-|-------|-------|
| grpc version | 4.x | 5.x |
| Proto encoding | Inline byte helpers | Typed `DummyMessage` class |
| WithHeaders call | No | Yes |

## Run

```sh
cd packages/grpc/example/grpc4
dart run lib/main.dart
```

Set your DSN in `lib/app_config.dart` before running.
