import 'package:sentry/sentry.dart';
import 'package:sentry_file/sentry_file.dart';
import 'dart:io';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

  // or SentryFlutter.init
  await Sentry.init(
    (options) {
      options.dsn = dsn;
      // To capture the absolute path of the file
      options.sendDefaultPii = true;
      // To set a uniform sample rate
      options.tracesSampleRate = 1.0;
    },
    appRunner: runApp, // Init your App.
  );
}

Future<void> runApp() async {
  final file = File('my_file.txt');
  // Call the Sentry extension method to wrap up the File
  final sentryFile = file.sentryTrace();

  // Start a transaction if there's no active transaction
  final transaction = Sentry.startTransaction(
    'MyFileExample',
    'file',
    bindToScope: true,
  );

  // Create the File
  await sentryFile.create();
  // Write some content
  await sentryFile.writeAsString('Hello World');
  // Read the content
  final text = await sentryFile.readAsString();

  print(text);

  // Delete the file
  await sentryFile.delete();

  // Finish the transaction
  await transaction.finish(status: SpanStatus.ok());

  await Sentry.close();
}
