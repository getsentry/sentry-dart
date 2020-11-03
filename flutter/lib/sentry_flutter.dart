import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:sentry/sentry.dart';

mixin SentryFlutter {
  static const _channel = MethodChannel('sentry_flutter');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static void _flutterErrorIntegration(Hub hub, SentryOptions options) {
    final defaultOnError = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails errorDetails) async {
      options.logger(
          SentryLevel.debug, 'Capture from onError ${errorDetails.exception}');

      // TODO: create mechanism

      await hub.captureException(
        errorDetails.exception,
        stackTrace: errorDetails.stack,
      );

      // call original handler
      if (defaultOnError != null) {
        defaultOnError(errorDetails);
      }

      // do we need this?
      // print('Capture from FlutterError ${details.exception}');
      // Zone.current.handleUncaughtError(details.exception, details.stack);
    };
  }

  static void _isolateErrorIntegration(Hub hub, SentryOptions options) {
    final receivePort = RawReceivePort(
      (dynamic error) async {
        options.logger(SentryLevel.debug, 'Capture from IsolateError $error');

        // TODO: create mechanism

        // https://api.dartlang.org/stable/2.7.0/dart-isolate/Isolate/addErrorListener.html
        // error is a list of 2 elements
        if (error is List<dynamic> && error.length == 2) {
          dynamic stackTrace = error.last;
          if (stackTrace != null) {
            stackTrace = StackTrace.fromString(stackTrace as String);
          }
          await Sentry.captureException(error.first, stackTrace: stackTrace);
        }
      },
    );

    Isolate.current.addErrorListener(receivePort.sendPort);
  }

  static Integration _runZonedGuardedIntegration(
    Function callback,
  ) {
    void integration(Hub hub, SentryOptions options) {
      runZonedGuarded(() {
        // it is necessary to initialize Flutter method channels so that
        // our plugin can call into the native code.
        WidgetsFlutterBinding.ensureInitialized();

        // TODO: we could read the window and add some stuff on contexts
        // final window = WidgetsBinding.instance.window;

        callback();
      }, (exception, stackTrace) async {
        // TODO: create mechanism

        await Sentry.captureException(
          exception,
          stackTrace: stackTrace,
        );
      });
    }

    return integration;
  }

  static void init(
    OptionsConfiguration optionsConfiguration,
    Function callback,
  ) {
    Sentry.init((options) {
      options.debug = kDebugMode;

      if (!kReleaseMode) {
        options.environment = 'debug';
      }

      // Throws when running on the browser
      if (!kIsWeb) {
        options.addIntegration(_isolateErrorIntegration);
      }
      options.addIntegration(_flutterErrorIntegration);
      options.addIntegration(_runZonedGuardedIntegration(callback));

      optionsConfiguration(options);
    });
  }
}
