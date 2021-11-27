import 'package:sentry_logging/sentry_logging.dart';
import 'dart:async';
import 'package:sentry/sentry.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  // ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
  const dsn =
      'https://9934c532bf8446ef961450973c898537@o447951.ingest.sentry.io/5428562';

  await Sentry.init(
    (options) {
      options.dsn = dsn;
      options.addIntegration(LoggingIntegration());
    },
    appRunner: runApp,
  );
}

Future<void> runApp() async {
  final log = Logger('MyAwesomeLogger');

  log.warning('a warning!');

  try {
    throw Exception();
  } catch (error, stackTrace) {
    // The log from above will be contained in this crash report.
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );
  }
}
