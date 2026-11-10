import 'package:grpc/grpc.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_grpc/sentry_grpc.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry.
  // Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init((options) {
    options.dsn = dsn;
    options.tracesSampleRate = 1.0;
    options.captureFailedRequests = true;
  }, appRunner: runApp);
}

Future<void> runApp() async {
  final channel = ClientChannel('api.example.com');
  final interceptors = <ClientInterceptor>[SentryGrpcInterceptor()];

  // Pass [interceptors] to your generated client:
  // final stub = GreeterClient(channel, interceptors: interceptors);

  await channel.shutdown();
  await Sentry.close();
}
