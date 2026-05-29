# grpc5 — sentry_grpc Dart example

Dart CLI example demonstrating `SentryGrpcInterceptor` with grpc 5.x.

## What it shows

- `Sentry.init` with `tracesSampleRate` and `captureFailedRequests`
- `SentryGrpcInterceptor` attached to a `ClientChannel` targeting `grpcb.in:9001`
- Request header capture in spans — the `WithHeaders` call passes `meat: vegetable` custom metadata, visible as `http.request.header.meat` in the span data
- Typed proto serialization via a hand-written `DummyMessage` class

## Calls

| Call | Endpoint | Purpose |
|------|----------|---------|
| Empty | `GRPCBin/Empty` | Successful unary RPC; creates a span |
| DummyUnary | `GRPCBin/DummyUnary` | Typed `DummyMessage` round-trip |
| RandomError | `GRPCBin/RandomError` | Randomly fails; tests error span + capture |
| WithHeaders | `GRPCBin/DummyUnary` + metadata | Verifies header capture in span data |

## Differences from grpc4

| | grpc4 | grpc5 |
|-|-------|-------|
| grpc version | 4.x | 5.x |
| Proto encoding | Inline byte helpers | Typed `DummyMessage` class |
| WithHeaders call | No | Yes |

## Run

```sh
cd packages/grpc/example/grpc5
dart run lib/main.dart
```

Set your DSN in `lib/app_config.dart` before running.
