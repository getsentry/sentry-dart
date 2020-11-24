import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_platform/universal_platform.dart';

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const String _exampleDsn =
    'https://cb0fad6f5d4e42ebb9c956cb0463edc9@o447951.ingest.sentry.io/5428562';

// Proposed init:
// https://github.com/bruno-garcia/badges.bar/blob/2450ed9125f7b73d2baad1fa6d676cc71858116c/lib/src/sentry.dart#L9-L32
Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = _exampleDsn;
    },
    () {
      // Init your App.
      runApp(MyApp());
    },
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sentry Flutter Example')),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const Center(child: Text('Trigger an action:\n')),
              RaisedButton(
                child: const Text('Dart: try catch'),
                onPressed: () => tryCatch(),
              ),
              RaisedButton(
                child: const Text('Flutter error : Scaffold.of()'),
                onPressed: () => Scaffold.of(context).showSnackBar(SnackBar(
                  content: Text(''),
                )),
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
                  child: const Text('Dart: async throws'),
                  onPressed: () async => asyncThrows().catchError(handleError)),
              RaisedButton(
                child: const Text('Dart: Fail in microtask.'),
                onPressed: () async => {
                  await Future.microtask(
                    () => throw StateError('Failure in a microtask'),
                  ).catchError(handleError)
                },
              ),
              RaisedButton(
                child: const Text('Dart: Fail in compute'),
                onPressed: () async =>
                    {await compute(loop, 10).catchError(handleError)},
              ),
              RaisedButton(
                child: const Text('Dart: Fail in compute'),
                onPressed: () async =>
                    {await compute(loop, 10).catchError(handleError)},
              ),
              if (UniversalPlatform.isIOS) const CocoaExample(),
              if (UniversalPlatform.isAndroid) const AndroidExample(),
              if (UniversalPlatform.isWeb) const WebExample(),
            ],
          ),
        ),
      ),
    );
  }
}

class AndroidExample extends StatelessWidget {
  const AndroidExample({Key key}) : super(key: key);

  final channel = const MethodChannel('example.flutter.sentry.io');

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RaisedButton(
        child: const Text('Kotlin Throw unhandled exception'),
        onPressed: () async {
          await execute('throw');
        },
      ),
      RaisedButton(
        child: const Text('Kotlin Capture Exception'),
        onPressed: () async {
          await execute('capture');
        },
      ),
      RaisedButton(
        // ANR is disabled by default, enable it to test it
        child: const Text('ANR: UI blocked 6 seconds'),
        onPressed: () async {
          await execute('anr');
        },
      ),
      RaisedButton(
        child: const Text('C++ Capture message'),
        onPressed: () async {
          await execute('cpp_capture_message');
        },
      ),
      RaisedButton(
        child: const Text('C++ SEGFAULT'),
        onPressed: () async {
          await execute('crash');
        },
      ),
    ]);
  }

  Future<void> execute(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } catch (error, stackTrace) {
      await Sentry.captureException(error, stackTrace: stackTrace);
    }
  }
}

Future<void> tryCatch() async {
  try {
    throw StateError('try catch');
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

Future<void> handleError(dynamic error, dynamic stackTrace) async {
  await Sentry.captureException(error, stackTrace: stackTrace);
}

Future<void> asyncThrows() async {
  throw StateError('async throws');
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

/// compute can only take a top-level function, but not instance or static methods.
// Top-level functions are functions declared not inside a class and not inside another function
int loop(int val) {
  int count = 0;
  for (int i = 1; i <= val; i++) {
    count += i;
  }

  throw StateError('from a compute isolate $count');
}
