import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_platform/universal_platform.dart';

const String _release =
    String.fromEnvironment('SENTRY_RELEASE', defaultValue: 'unknown');

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const String _exampleDsn =
    'https://cb0fad6f5d4e42ebb9c956cb0463edc9@o447951.ingest.sentry.io/5428562';

// Proposed init:
// https://github.com/bruno-garcia/badges.bar/blob/2450ed9125f7b73d2baad1fa6d676cc71858116c/lib/src/sentry.dart#L9-L32
Future<void> main() async {
  await SentryFlutter.init((options) {
    options.dsn = _exampleDsn;
    // TODO: we probably need to solve this
    options.addInAppInclude('sentry_flutter_example');
  }, initMyApp);
}

void initMyApp() {
  // code before
  runApp(MyApp());
  // code after
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
      // platformVersion = await SentryFlutter.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) {
      return;
    }

    setState(() => _platformVersion = platformVersion);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sentry Flutter Example')),
        body: Column(
          children: [
            Center(child: Text('Running on: $_platformVersion\n')),
            const Center(child: Text('Release: $_release\n')),
            RaisedButton(
              child: const Text('Dart: try catch'),
              onPressed: () => tryCatch(),
            ),
            RaisedButton(
              child: const Text('Dart: throw null'),
              // Warning : not captured if a debugger is attached
              // https://github.com/flutter/flutter/issues/48972
              onPressed: () => throw null,
            ),
            RaisedButton(
              child: const Text('Dart: assert'),
              onPressed: () {
                // Only relevant in debug builds
                // Warning : not captured if a debugger is attached
                // https://github.com/flutter/flutter/issues/48972
                assert(false, 'assert failure');
              },
            ),
            RaisedButton(
              child: const Text('Dart: Fail in microtask.'),
              onPressed: () async => {
                await Future.microtask(
                  () => throw StateError('Failure in a microtask'),
                )
              },
            ),
            RaisedButton(
              child: const Text('Dart: Fail in isolate'),
              onPressed: () async => {
                await compute(
                  (Object _) => throw StateError('from an isolate'),
                  null,
                )
              },
            ),
            if (UniversalPlatform.isIOS) const CocoaExample(),
            if (UniversalPlatform.isAndroid) const AndroidExample(),
            if (UniversalPlatform.isWeb) const WebExample(),
          ],
        ),
      ),
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

Future<void> tryCatch() async {
  try {
    throw StateError('whats happening here');
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

class CocoaExample extends StatelessWidget {
  const CocoaExample({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      ],
    );
  }
}

class WebExample extends StatelessWidget {
  const WebExample({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RaisedButton(
          child: const Text('Web: console.log'),
          onPressed: () async {
            const channel = MethodChannel('example.flutter.sentry.io');
            await channel.invokeMethod<void>('console.log');
          },
        ),
      ],
    );
  }
}
