import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:sentry/sentry.dart';

// NOTE: Add your DSN below to get the events in your Sentry project.
final SentryClient _sentry = SentryClient(
    dsn:
        'https://39226a237e6b4fa5aae9191fa5732814@o19635.ingest.sentry.io/2078115');

// Proposed init:
// https://github.com/bruno-garcia/badges.bar/blob/2450ed9125f7b73d2baad1fa6d676cc71858116c/lib/src/sentry.dart#L9-L32
Future<void> main() async {
  // Needs to move into the library
  FlutterError.onError = (FlutterErrorDetails details) async {
    print('Capture from FlutterError ${details.exception}');
    Zone.current.handleUncaughtError(details.exception, details.stack);
  };
  Isolate.current.addSentryErrorListener(_sentry);

  runZonedGuarded<Future<void>>(() async {
    runApp(MyApp());
  }, (error, stackTrace) async {
    print('Capture from runZonedGuarded $error');
    await _sentry.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  });
}

// Candidate API for the SDK
extension IsolateExtensions on Isolate {
  void addSentryErrorListener(SentryClient sentry) {
    final receivePort = RawReceivePort((dynamic values) async {
      await sentry.captureIsolateError(values);
    });

    Isolate.current.addErrorListener(receivePort.sendPort);
  }
}

// Candidate API for the SDK
extension SentryExtensions on SentryClient {
  Future<void> captureIsolateError(dynamic error) {
    print('Capture from IsolateError $error');

    if (error is List<dynamic> && error.length != 2) {
      dynamic stackTrace = error[1];
      if (stackTrace != null) {
        stackTrace = StackTrace.fromString(stackTrace as String);
      }
      return captureException(exception: error[0], stackTrace: stackTrace);
    } else {
      return Future.value();
    }
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await SentryFlutter.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return;
    }

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> init() async {
    const platform = MethodChannel('io.sentry.flutter.manchestermaps/kmlLayer');
    try {
      final dynamic campusMapOverlay =
          await platform.invokeMethod<dynamic>('retrieveFileFromUrl');
      print(campusMapOverlay);
    } on PlatformException catch (error) {
      print(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Sentry Flutter Example.'),
        ),
        body: Column(
          children: [
            Center(
              child: Text('Running on: $_platformVersion\n'),
            ),
            RaisedButton(
                child: const Text('Dart: throw null'),
                onPressed: () => throw null),
            RaisedButton(
                child: const Text('Dart: Fail in microtask.'),
                onPressed: () async => {
                      await Future.microtask(
                          () => throw StateError('Failure in a microtask.'))
                    }),
            RaisedButton(
                child: const Text('Dart: Fail in isolate.'),
                onPressed: () async => {
                      await compute(
                          (void _) => print('where is the bug?'), null)
                    }),
            RaisedButton(
              child: const Text('Platform: MethodChannel unknown method.'),
              onPressed: () async {
                const channel = MethodChannel('method_channel');
                await channel.invokeMethod<void>('unknown');
              },
            ),
          ],
        ),
      ),
    );
  }
}
