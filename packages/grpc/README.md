<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Sentry integration for `gRPC` package

| package      | build                                                                                                                                                                                  | pub                                                                                                    | likes                                                                                                  | popularity                                                                                                       | pub points                                                                                                   |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| sentry_grpc | [![build](https://github.com/getsentry/sentry-dart/actions/workflows/grpc.yml/badge.svg?branch=main)](https://github.com/getsentry/sentry-dart/actions?query=workflow%3Asentry-grpc) | [![pub package](https://img.shields.io/pub/v/sentry_grpc.svg)](https://pub.dev/packages/sentry_grpc) | [![likes](https://img.shields.io/pub/likes/sentry_grpc)](https://pub.dev/packages/sentry_grpc/score) | [![popularity](https://img.shields.io/pub/popularity/sentry_grpc)](https://pub.dev/packages/sentry_grpc/score) | [![pub points](https://img.shields.io/pub/points/sentry_grpc)](https://pub.dev/packages/sentry_grpc/score) |

Integration for the [`gRPC`](https://pub.dev/packages/grpc) package.

#### Usage

- Sign up for a Sentry.io account and get a DSN at https://sentry.io.

- Follow the installing instructions on [pub.dev](https://pub.dev/packages/sentry/install).

- Initialize the Sentry SDK using the DSN issued by Sentry.io.

- Call your client with the gRPC interceptor `SentryGrpcInterceptor` and you should get gRPC integration out of the box.

```dart
import 'package:grpc/grpc.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_grpc/sentry_grpc.dart';

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example';
      options.tracesSampleRate = 1.0;
      options.captureFailedRequests = true;
    },
    appRunner: runApp,
  );
}

Future<void> runApp() async {
  final channel = ClientChannel(
    'api.example.com',
    options: const ChannelOptions(credentials: ChannelCredentials.secure()),
  );

  final client = MyServiceClient(
    channel,
    interceptors: [SentryGrpcInterceptor()],
  );

  // Calls are now automatically instrumented with Sentry tracing
  // and failed requests are captured as Sentry exceptions.
}
```

#### Resources

- [![Flutter docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=flutter%20docs)](https://docs.sentry.io/platforms/flutter/)
- [![Dart docs](https://img.shields.io/badge/documentation-sentry.io-green.svg?label=dart%20docs)](https://docs.sentry.io/platforms/dart/)
- [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-dart.svg)](https://github.com/getsentry/sentry-dart/discussions)
- [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.gg/gB6ja9uZuN)
- [![Stack Overflow](https://img.shields.io/badge/stack%20overflow-sentry-green.svg)](https://stackoverflow.com/questions/tagged/sentry)
- [![Twitter Follow](https://img.shields.io/twitter/follow/getsentry?label=getsentry&style=social)](https://twitter.com/intent/follow?screen_name=getsentry)
