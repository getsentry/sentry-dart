import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:sentry/sentry.dart';
import 'package:universal_platform/universal_platform.dart';

const String _release =
    String.fromEnvironment('SENTRY_RELEASE', defaultValue: 'unknown');

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

  if (!kIsWeb) {
    // Throws when running on the browser
    Isolate.current.addSentryErrorListener(_sentry);
  }

  runZonedGuarded<Future<void>>(() async {
    runApp(MyApp());
  }, (error, stackTrace) async {
    print('Capture from runZonedGuarded $error');
    final event = Event(
        exception: error,
        stackTrace: stackTrace,
        // release is required on Web to match the source maps
        release: _release);
    await _sentry.capture(event: event);
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
          title: const Text('Sentry Flutter Example'),
        ),
        body: Column(
          children: [
            Center(
              child: Text('Running on: $_platformVersion\n'),
            ),
            const Center(
              child: Text('Release: $_release\n'),
            ),
            RaisedButton(
                child: const Text('Dart: throw null'),
                onPressed: () => throw null),
            RaisedButton(
                child: const Text('Dart: assert'),
                onPressed: () {
                  // Only relevant in debug builds
                  assert(false, 'assert failure');
                }),
            RaisedButton(
                child: const Text('Dart: Fail in microtask.'),
                onPressed: () async => {
                      await Future.microtask(
                          () => throw StateError('Failure in a microtask'))
                    }),
            RaisedButton(
                child: const Text('Dart: Fail in isolate'),
                onPressed: () async => {
                      await compute(
                          (Object _) => throw StateError('from an isolate'),
                          null)
                    }),
            const PlatformExample()
          ],
        ),
      ),
    );
  }
}

class PlatformExample extends StatelessWidget {
  const PlatformExample({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (UniversalPlatform.isIOS)
          const CocoaExample()
        else if (UniversalPlatform.isAndroid)
          const AndroidExample()
        else if (UniversalPlatform.isWeb)
          const WebExample()
      ],
    );
  }
}

class AndroidExample extends StatelessWidget {
  const AndroidExample({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RaisedButton(
        child: const Text('Kotlin Throw unhandled exception'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('throw');
        },
      ),
      RaisedButton(
        child: const Text('Kotlin Capture Exception'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('capture');
        },
      ),
      RaisedButton(
        child: const Text('Kotlin Background thread error'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('background');
        },
      ),
      RaisedButton(
        child: const Text('ANR: UI blocked 6 seconds'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('anr');
        },
      ),
      RaisedButton(
        child: const Text('C++ Capture message'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('cpp_capture_message');
        },
      ),
      RaisedButton(
        child: const Text('C++ SEGFAULT'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('crash');
        },
      ),
    ]);
  }
}

class CocoaExample extends StatelessWidget {
  const CocoaExample({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RaisedButton(
        child: const Text('Swift fatalError'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('fatalError');
        },
      ),
      RaisedButton(
        child: const Text('Swift Capture NSException'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('capture');
        },
      ),
      RaisedButton(
        child: const Text('Swift Capture message'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('capture_message');
        },
      ),
      RaisedButton(
        child: const Text('Objective-C Throw unhandled exception'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('throw');
        },
      ),
      RaisedButton(
        child: const Text('Objective-C SEGFAULT'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('crash');
        },
      ),
    ]);
  }
}

class WebExample extends StatelessWidget {
  const WebExample({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RaisedButton(
        child: const Text('Web: console.log'),
        onPressed: () async {
          const channel = MethodChannel('example.flutter.sentry.io');
          await channel.invokeMethod<void>('console.log');
        },
      ),
    ]);
  }
}
