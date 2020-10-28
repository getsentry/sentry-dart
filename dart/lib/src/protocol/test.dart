import 'dart:async';
import 'package:sentry/sentry.dart';

// Wrap your 'runApp(MyApp())' as follows:

void main() async {
  runZonedGuarded(
    () => runApp(MyApp()),
        (error, stackTrace) {
          Sentry.captureException(
            exception: error,
            stackTrace: stackTrace,
          );
        },
      );
    }
    
    
}

class MyApp {
  runApp(MyApp myApp) {
  }
}
