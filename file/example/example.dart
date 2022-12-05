import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'dart:io';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.debug = true;
      options.sendDefaultPii = true;
      options.tracesSampleRate = 1.0;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final file = File('my_file.txt');
  final sentryFile = file.sentryTrace();

  final transaction = Sentry.startTransaction(
    'MyFileExample',
    'file',
    bindToScope: true,
  );

  await sentryFile.create();
  await sentryFile.writeAsString('Hello World');
  final text = await sentryFile.readAsString();

  print(text);

  await sentryFile.delete();

  await transaction.finish(status: SpanStatus.ok());

  await Sentry.close();
}
