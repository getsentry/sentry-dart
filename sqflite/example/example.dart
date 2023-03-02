import 'package:sentry/sentry.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.tracesSampleRate = 1.0;
      options.debug = true;
      options.sendDefaultPii = true;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final transaction = Sentry.startTransaction(
    'sqflite-query',
    'db',
    bindToScope: true,
  );

  try {} catch (exception) {
    transaction.throwable = exception;
    transaction.status = const SpanStatus.internalError();
  } finally {
    await transaction.finish();
  }

  await Sentry.close();
}
