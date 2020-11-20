import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/add-your-dsn-here';
      // Change the 'sentry_flutter_example' below with your own package.
      options.addInAppInclude('sentry_flutter_example');
    },
    (Function callback) => {
      // Init your App.
      runApp(MyApp()),
    },
  );

  try {
    aMethodThatMightFail();
  } catch (exception, stackTrace) {
    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
    );
  }
}

void aMethodThatMightFail() {
  throw null;
}
