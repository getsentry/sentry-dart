// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:feedback/feedback.dart' as feedback;
import 'package:provider/provider.dart';
import 'user_feedback_dialog.dart';
import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_logging/sentry_logging.dart';

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const String _exampleDsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

const _channel = MethodChannel('example.flutter.sentry.io');

Future<void> main() async {
  await setupSentry(() => runApp(
        SentryScreenshotWidget(
          child: SentryUserInteractionWidget(
            child: DefaultAssetBundle(
              bundle: SentryAssetBundle(enableStructuredDataTracing: true),
              child: const MyApp(),
            ),
          ),
        ),
      ));
}

Future<void> setupSentry(AppRunner appRunner) async {
  await SentryFlutter.init((options) {
    options.dsn = _exampleDsn;
    options.tracesSampleRate = 1.0;
    options.reportPackages = false;
    options.addInAppInclude('sentry_flutter_example');
    options.considerInAppFramesByDefault = false;
    options.attachThreads = true;
    options.enableWindowMetricBreadcrumbs = true;
    options.addIntegration(LoggingIntegration());
    options.sendDefaultPii = true;
    options.reportSilentFlutterErrors = true;
    options.enableNdkScopeSync = true;
    options.enableUserInteractionTracing = true;
    options.attachScreenshot = true;
    // We can enable Sentry debug logging during development. This is likely
    // going to log too much for your app, but can be useful when figuring out
    // configuration issues, e.g. finding out why your events are not uploaded.
    options.debug = true;
  },
      // Init your App.
      appRunner: appRunner);
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return feedback.BetterFeedback(
      child: ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorObservers: [
              SentryNavigatorObserver(),
            ],
            theme: Provider.of<ThemeProvider>(context).theme,
            home: const MainScaffold(),
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    var icon = Icons.light_mode;
    var theme = ThemeData.light();
    if (themeProvider.theme.brightness == Brightness.light) {
      icon = Icons.dark_mode;
      theme = ThemeData.dark();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentry Flutter Example'),
        actions: [
          IconButton(
            onPressed: () {
              themeProvider.theme = theme;
            },
            icon: Icon(icon),
          ),
          IconButton(
            onPressed: () {
              themeProvider.updatePrimatryColor(Colors.orange);
            },
            icon: const Icon(Icons.circle, color: Colors.orange),
          ),
          IconButton(
            onPressed: () {
              themeProvider.updatePrimatryColor(Colors.green);
            },
            icon: const Icon(Icons.circle, color: Colors.lime),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Center(child: Text('Trigger an action:\n')),
            ElevatedButton(
              onPressed: () => SecondaryScaffold.openSecondaryScaffold(context),
              child: const Text('Open another Scaffold'),
            ),
            ElevatedButton(
              onPressed: () => tryCatch(),
              key: const Key('dart_try_catch'),
              child: const Text('Dart: try catch'),
            ),
            ElevatedButton(
              onPressed: () => Scaffold.of(context).showBottomSheet<dynamic>(
                (context) => const Text('Scaffold error'),
              ),
              child: const Text('Flutter error : Scaffold.of()'),
            ),
            ElevatedButton(
              // Warning : not captured if a debugger is attached
              // https://github.com/flutter/flutter/issues/48972
              onPressed: () => throw Exception('Throws onPressed'),
              child: const Text('Dart: throw onPressed'),
            ),
            ElevatedButton(
              onPressed: () {
                // Only relevant in debug builds
                // Warning : not captured if a debugger is attached
                // https://github.com/flutter/flutter/issues/48972
                assert(false, 'assert failure');
              },
              child: const Text('Dart: assert'),
            ),
            // Calling the SDK with an appRunner will handle errors from Futures
            // in SDKs runZonedGuarded onError handler
            ElevatedButton(
              onPressed: () async => asyncThrows(),
              child: const Text('Dart: async throws'),
            ),
            ElevatedButton(
              onPressed: () async => {
                await Future.microtask(
                  () => throw StateError('Failure in a microtask'),
                )
              },
              child: const Text('Dart: Fail in microtask.'),
            ),
            ElevatedButton(
              onPressed: () async => {await compute(loop, 10)},
              child: const Text('Dart: Fail in compute'),
            ),
            ElevatedButton(
              onPressed: () => Future.delayed(
                const Duration(milliseconds: 100),
                () => throw Exception('Throws in Future.delayed'),
              ),
              child: const Text('Throws in Future.delayed'),
            ),
            ElevatedButton(
              onPressed: () {
                // modeled after a real exception
                FlutterError.onError?.call(FlutterErrorDetails(
                  exception: Exception('A really bad exception'),
                  silent: false,
                  context: DiagnosticsNode.message('while handling a gesture'),
                  library: 'gesture',
                  informationCollector: () => [
                    DiagnosticsNode.message(
                        'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                    DiagnosticsNode.message(
                        'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                    DiagnosticsNode.message(
                        'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                  ],
                ));
              },
              child: const Text('Capture from FlutterError.onError'),
            ),
            ElevatedButton(
              onPressed: () => makeWebRequest(context),
              child: const Text('Dart: Web request'),
            ),
            ElevatedButton(
              onPressed: () => showDialogWithTextAndImage(context),
              child: const Text('Flutter: Load assets'),
            ),
            ElevatedButton(
              key: const Key('dio_web_request'),
              onPressed: () async => await makeWebRequestWithDio(context),
              child: const Text('Dio: Web request'),
            ),
            ElevatedButton(
              onPressed: () {
                // ignore: avoid_print
                print('A print breadcrumb');
                Sentry.captureMessage('A message with a print() Breadcrumb');
              },
              child: const Text('Record print() as breadcrumb'),
            ),
            ElevatedButton(
              onPressed: () {
                Sentry.captureMessage(
                  'This event has an extra tag',
                  withScope: (scope) {
                    scope.setTag('foo', 'bar');
                  },
                );
              },
              child:
                  const Text('Capture message with scope with additional tag'),
            ),
            ElevatedButton(
              onPressed: () async {
                final transaction = Sentry.getSpan() ??
                    Sentry.startTransaction(
                      'myNewTrWithError3',
                      'myNewOp',
                      description: 'myTr myOp',
                    );
                transaction.setTag('myTag', 'myValue');
                transaction.setData('myExtra', 'myExtraValue');

                await Future.delayed(const Duration(milliseconds: 50));

                final span = transaction.startChild(
                  'childOfMyOp',
                  description: 'childOfMyOp span',
                );
                span.setTag('myNewTag', 'myNewValue');
                span.setData('myNewData', 'myNewDataValue');

                await Future.delayed(const Duration(milliseconds: 70));

                await span.finish(status: const SpanStatus.resourceExhausted());

                await Future.delayed(const Duration(milliseconds: 90));

                final spanChild = span.startChild(
                  'childOfChildOfMyOp',
                  description: 'childOfChildOfMyOp span',
                );

                await Future.delayed(const Duration(milliseconds: 110));

                spanChild.startChild(
                  'unfinishedChild',
                  description: 'I wont finish',
                );

                await spanChild.finish(
                    status: const SpanStatus.internalError());

                await Future.delayed(const Duration(milliseconds: 50));

                await transaction.finish(status: const SpanStatus.ok());
              },
              child: const Text('Capture transaction'),
            ),
            ElevatedButton(
              onPressed: () {
                Sentry.captureMessage(
                  'This message has an attachment',
                  withScope: (scope) {
                    const txt = 'Lorem Ipsum dolar sit amet';
                    scope.addAttachment(
                      SentryAttachment.fromIntList(
                        utf8.encode(txt),
                        'foobar.txt',
                        contentType: 'text/plain',
                      ),
                    );
                  },
                );
              },
              child: const Text('Capture message with attachment'),
            ),
            ElevatedButton(
              onPressed: () {
                feedback.BetterFeedback.of(context)
                    .show((feedback.UserFeedback feedback) {
                  Sentry.captureMessage(
                    feedback.text,
                    withScope: (scope) {
                      final entries = feedback.extra?.entries;
                      if (entries != null) {
                        for (final extra in entries) {
                          scope.setExtra(extra.key, extra.value);
                        }
                      }
                      scope.addAttachment(
                        SentryAttachment.fromUint8List(
                          feedback.screenshot,
                          'feedback.png',
                          contentType: 'image/png',
                        ),
                      );
                    },
                  );
                });
              },
              child: const Text('Capture message with image attachment'),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = await Sentry.captureMessage('UserFeedback');
                await showDialog(
                  context: context,
                  builder: (context) {
                    return UserFeedbackDialog(eventId: id);
                  },
                );
              },
              child: const Text('Capture User Feedback'),
            ),
            ElevatedButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) {
                    return UserFeedbackDialog(eventId: SentryId.newId());
                  },
                );
              },
              child: const Text('Show UserFeedback Dialog without event'),
            ),
            if (UniversalPlatform.isIOS || UniversalPlatform.isMacOS)
              const CocoaExample(),
            if (UniversalPlatform.isAndroid) const AndroidExample(),
          ],
        ),
      ),
    );
  }
}

class AndroidExample extends StatelessWidget {
  const AndroidExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ElevatedButton(
        onPressed: () async {
          await execute('throw');
        },
        child: const Text('Kotlin Throw unhandled exception'),
      ),
      ElevatedButton(
        onPressed: () async {
          await execute('capture');
        },
        child: const Text('Kotlin Capture Exception'),
      ),
      ElevatedButton(
        // ANR is disabled by default, enable it to test it
        onPressed: () async {
          await execute('anr');
        },
        child: const Text('ANR: UI blocked 6 seconds'),
      ),
      ElevatedButton(
        onPressed: () async {
          await execute('cpp_capture_message');
        },
        child: const Text('C++ Capture message'),
      ),
      ElevatedButton(
        onPressed: () async {
          await execute('crash');
        },
        child: const Text('C++ SEGFAULT'),
      ),
      ElevatedButton(
        onPressed: () async {
          await execute('platform_exception');
        },
        child: const Text('Platform exception'),
      ),
      ElevatedButton(
        onPressed: () {
          final log = Logger('Logging');
          log.info('My Logging test');
        },
        child: const Text('Logging'),
      ),
    ]);
  }
}

Future<void> tryCatch() async {
  try {
    throw StateError('try catch');
  } catch (error, stackTrace) {
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

Future<void> asyncThrows() async {
  throw StateError('async throws');
}

class CocoaExample extends StatelessWidget {
  const CocoaExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            await execute('fatalError');
          },
          child: const Text('Swift fatalError'),
        ),
        ElevatedButton(
          onPressed: () async {
            await execute('capture');
          },
          child: const Text('Swift Capture NSException'),
        ),
        ElevatedButton(
          onPressed: () async {
            await execute('capture_message');
          },
          child: const Text('Swift Capture message'),
        ),
        ElevatedButton(
          onPressed: () async {
            await execute('throw');
          },
          child: const Text('Objective-C Throw unhandled exception'),
        ),
        ElevatedButton(
          onPressed: () async {
            await execute('crash');
          },
          child: const Text('Objective-C SEGFAULT'),
        ),
      ],
    );
  }
}

/// compute can only take a top-level function, but not instance or static methods.
// Top-level functions are functions declared not inside a class and not inside another function
int loop(int val) {
  var count = 0;
  for (var i = 1; i <= val; i++) {
    count += i;
  }

  throw StateError('from a compute isolate $count');
}

class SecondaryScaffold extends StatelessWidget {
  const SecondaryScaffold({Key? key}) : super(key: key);

  static Future<void> openSecondaryScaffold(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings:
            const RouteSettings(name: 'SecondaryScaffold', arguments: 'foobar'),
        builder: (context) {
          return const SecondaryScaffold();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecondaryScaffold'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text(
              'You have added a navigation event '
              'to the crash reports breadcrumbs.',
            ),
            MaterialButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go back'),
            ),
            MaterialButton(
              onPressed: () {
                throw Exception('Exception from SecondaryScaffold');
              },
              child: const Text('throw uncaught exception'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> makeWebRequest(BuildContext context) async {
  final transaction = Sentry.getSpan() ??
      Sentry.startTransaction(
        'flutterwebrequest',
        'request',
        bindToScope: true,
      );

  final client = SentryHttpClient(
    captureFailedRequests: true,
    maxRequestBodySize: MaxRequestBodySize.always,
    networkTracing: true,
    failedRequestStatusCodes: [SentryStatusCode.range(400, 500)],
  );
  // We don't do any exception handling here.
  // In case of an exception, let it get caught and reported to Sentry
  final response = await client.get(Uri.parse('https://flutter.dev/'));

  await transaction.finish(status: const SpanStatus.ok());

  await showDialog<void>(
    context: context,
    // gets tracked if using SentryNavigatorObserver
    routeSettings: const RouteSettings(
      name: 'flutter.dev dialog',
    ),
    builder: (context) {
      return AlertDialog(
        title: Text('Response ${response.statusCode}'),
        content: SingleChildScrollView(
          child: Text(response.body),
        ),
        actions: [
          MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      );
    },
  );
}

Future<void> makeWebRequestWithDio(BuildContext context) async {
  final dio = Dio();

  dio.addSentry(
    captureFailedRequests: true,
    maxRequestBodySize: MaxRequestBodySize.always,
    maxResponseBodySize: MaxResponseBodySize.always,
  );

  final transaction = Sentry.getSpan() ??
      Sentry.startTransaction(
        'dio-web-request',
        'request',
        bindToScope: true,
      );
  final span = transaction.startChild(
    'dio',
    description: 'desc',
  );
  Response<String>? response;
  try {
    response = await dio.get<String>('https://flutter.dev/');
    span.status = const SpanStatus.ok();
  } catch (exception, stackTrace) {
    span.throwable = exception;
    span.status = const SpanStatus.internalError();
    await Sentry.captureException(exception, stackTrace: stackTrace);
  } finally {
    await span.finish();
  }

  await showDialog<void>(
    context: context,
    // gets tracked if using SentryNavigatorObserver
    routeSettings: const RouteSettings(
      name: 'flutter.dev dialog',
    ),
    builder: (context) {
      return AlertDialog(
        title: Text('Response ${response?.statusCode}'),
        content: SingleChildScrollView(
          child: Text(response?.data ?? 'failed request'),
        ),
        actions: [
          MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      );
    },
  );
}

Future<void> showDialogWithTextAndImage(BuildContext context) async {
  final transaction = Sentry.getSpan() ??
      Sentry.startTransaction(
        'asset-bundle-transaction',
        'load',
        bindToScope: true,
      );
  final text =
      await DefaultAssetBundle.of(context).loadString('assets/lorem-ipsum.txt');
  await showDialog<void>(
    context: context,
    // gets tracked if using SentryNavigatorObserver
    routeSettings: const RouteSettings(
      name: 'AssetBundle dialog',
    ),
    builder: (context) {
      return AlertDialog(
        title: const Text('Asset Example'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/sentry-wordmark.png'),
              Text(text),
            ],
          ),
        ),
        actions: [
          MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      );
    },
  );
  await transaction.finish(status: const SpanStatus.ok());
}

class ThemeProvider extends ChangeNotifier {
  ThemeData _theme = ThemeData.light();

  ThemeData get theme => _theme;

  set theme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  void updatePrimatryColor(MaterialColor color) {
    if (theme.brightness == Brightness.light) {
      theme = ThemeData(primarySwatch: color, brightness: theme.brightness);
    } else {
      theme = ThemeData(primarySwatch: color, brightness: theme.brightness);
    }
  }
}

Future<void> execute(String method) async {
  await _channel.invokeMethod(method);
}
