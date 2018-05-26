import 'package:sentry/sentry.dart';

// create a SentryClient using the DSN issued by Sentry.io
final SentryClient sentry = new SentryClient(dsn: YOUR_DSN);

// In an exception handler, call captureException():
main() async {
  try {
    doSomethingThatMightThrowAnError();
  } catch(error, stackTrace) {
    await sentry.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  }
}
