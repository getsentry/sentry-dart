// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_drift/sentry_drift.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_isar/sentry_isar.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sqflite/sqflite.dart';

// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:feedback/feedback.dart' as feedback;
import 'package:provider/provider.dart';
import 'auto_close_screen.dart';
import 'drift/database.dart';
import 'drift/connection/connection.dart';
import 'isar/user.dart';
import 'user_feedback_dialog.dart';
import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:sentry_hive/sentry_hive.dart';

// ATTENTION: Change the DSN below with your own to see the events in Sentry. Get one at sentry.io
const String exampleDsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

/// This is an exampleUrl that will be used to demonstrate how http requests are captured.
const String exampleUrl = 'https://jsonplaceholder.typicode.com/todos/';

const _channel = MethodChannel('example.flutter.sentry.io');
var _isIntegrationTest = false;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await setupSentry(
    () => runApp(
      SentryWidget(
        child: DefaultAssetBundle(
          bundle: SentryAssetBundle(),
          child: const MyApp(),
        ),
      ),
    ),
    exampleDsn,
  );
}

Future<void> setupSentry(
  AppRunner appRunner,
  String dsn, {
  bool isIntegrationTest = false,
  BeforeSendCallback? beforeSendCallback,
}) async {
  await SentryFlutter.init(
    (options) {
      options.dsn = exampleDsn;
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
      options.reportPackages = false;
      options.addInAppInclude('sentry_flutter_example');
      options.considerInAppFramesByDefault = false;
      options.attachThreads = true;
      options.enableWindowMetricBreadcrumbs = true;
      options.addIntegration(LoggingIntegration(minEventLevel: Level.INFO));
      options.sendDefaultPii = true;
      options.reportSilentFlutterErrors = true;
      options.attachScreenshot = true;
      options.screenshotQuality = SentryScreenshotQuality.low;
      options.attachViewHierarchy = true;
      // We can enable Sentry debug logging during development. This is likely
      // going to log too much for your app, but can be useful when figuring out
      // configuration issues, e.g. finding out why your events are not uploaded.
      options.debug = true;
      options.spotlight = Spotlight(enabled: true);
      options.enableTimeToFullDisplayTracing = true;
      options.enableMetrics = true;

      options.maxRequestBodySize = MaxRequestBodySize.always;
      options.maxResponseBodySize = MaxResponseBodySize.always;
      options.navigatorKey = navigatorKey;

      _isIntegrationTest = isIntegrationTest;
      if (_isIntegrationTest) {
        options.dist = '1';
        options.environment = 'integration';
        options.beforeSend = beforeSendCallback;
      }
    },
    // Init your App.
    appRunner: appRunner,
  );
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
            navigatorKey: navigatorKey,
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

class TooltipButton extends StatelessWidget {
  final String text;
  final String buttonTitle;
  final void Function()? onPressed;

  const TooltipButton({
    required this.onPressed,
    required this.buttonTitle,
    required this.text,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: ElevatedButton(
        onPressed: onPressed,
        key: key,
        child: Text(buttonTitle),
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
              themeProvider.updatePrimaryColor(Colors.orange);
            },
            icon: const Icon(Icons.circle, color: Colors.orange),
          ),
          IconButton(
            onPressed: () {
              themeProvider.updatePrimaryColor(Colors.green);
            },
            icon: const Icon(Icons.circle, color: Colors.lime),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_isIntegrationTest) const IntegrationTestWidget(),
            const Center(child: Text('Trigger an action.\n')),
            const Padding(
              padding: EdgeInsets.all(15), //apply padding to all four sides
              child: Center(
                child: Text(
                    'Long press a button to see more information. (hover on web)'),
              ),
            ),
            TooltipButton(
              onPressed: () => navigateToAutoCloseScreen(context),
              text:
                  'Pushes a screen and creates a transaction named \'AutoCloseScreen\' with a child span that finishes after 3 seconds. \nAfter the screen has popped the transaction can then be seen on the performance page.',
              buttonTitle: 'Route Navigation Observer',
            ),
            if (!UniversalPlatform.isWeb)
              TooltipButton(
                onPressed: driftTest,
                text:
                    'Executes CRUD operations on an in-memory with Drift and sends the created transaction to Sentry.',
                buttonTitle: 'drift',
              ),
            if (!UniversalPlatform.isWeb)
              TooltipButton(
                onPressed: hiveTest,
                text:
                    'Executes CRUD operations on an in-memory with Hive and sends the created transaction to Sentry.',
                buttonTitle: 'hive',
              ),
            if (!UniversalPlatform.isWeb)
              TooltipButton(
                onPressed: isarTest,
                text:
                    'Executes CRUD operations on an in-memory with Isart and sends the created transaction to Sentry.',
                buttonTitle: 'isar',
              ),
            TooltipButton(
              onPressed: sqfliteTest,
              text:
                  'Executes CRUD operations on an in-memory with Hive and sends the created transaction to Sentry.',
              buttonTitle: 'sqflite',
            ),
            TooltipButton(
              onPressed: () => SecondaryScaffold.openSecondaryScaffold(context),
              text:
                  'Demonstrates how the router integration adds a navigation event to the breadcrumbs that can be seen when throwing an exception for example.',
              buttonTitle: 'Open another Scaffold',
            ),
            const TooltipButton(
              onPressed: tryCatch,
              key: Key('dart_try_catch'),
              text: 'Creates a caught exception and sends it to Sentry.',
              buttonTitle: 'Dart: try catch',
            ),
            TooltipButton(
              onPressed: () => Scaffold.of(context)
                  .showBottomSheet((context) => const Text('Scaffold error')),
              text:
                  'Creates an uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Flutter error : Scaffold.of()',
            ),
            TooltipButton(
              // Warning : not captured if a debugger is attached
              // https://github.com/flutter/flutter/issues/48972
              onPressed: () => throw Exception('Throws onPressed'),
              text:
                  'Creates an uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Dart: throw onPressed',
            ),
            TooltipButton(
              // Warning : not captured if a debugger is attached
              // https://github.com/flutter/flutter/issues/48972
              onPressed: () {
                assert(false, 'assert failure');
              },
              text:
                  'Creates an uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Dart: assert',
            ),
            // Calling the SDK with an appRunner will handle errors from Futures
            // in SDKs runZonedGuarded onError handler
            TooltipButton(
              onPressed: () async => asyncThrows(),
              text:
                  'Creates an async uncaught exception and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Dart: async throws',
            ),
            TooltipButton(
              onPressed: () async => {
                await Future.microtask(
                  () => throw StateError('Failure in a microtask'),
                )
              },
              text:
                  'Creates an uncaught exception in a microtask and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Dart: Fail in microtask',
            ),
            TooltipButton(
              onPressed: () async => {
                await compute(loop, 10),
              },
              text:
                  'Creates an uncaught exception in a compute isolate and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Dart: Fail in compute',
            ),
            TooltipButton(
              onPressed: () async => {
                await Future.delayed(
                  const Duration(milliseconds: 100),
                  () => throw StateError('Failure in a Future.delayed'),
                ),
              },
              text:
                  'Creates an uncaught exception in a Future.delayed and sends it to Sentry. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Throws in Future.delayed',
            ),
            TooltipButton(
              onPressed: () {
                // modeled after a real exception
                FlutterError.onError?.call(
                  FlutterErrorDetails(
                    exception: Exception('A really bad exception'),
                    silent: false,
                    context:
                        DiagnosticsNode.message('while handling a gesture'),
                    library: 'gesture',
                    informationCollector: () => [
                      DiagnosticsNode.message(
                          'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                      DiagnosticsNode.message(
                          'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                      DiagnosticsNode.message(
                          'Handler: "onTap" Recognizer: TapGestureRecognizer'),
                    ],
                  ),
                );
              },
              text:
                  'Creates a FlutterError and passes it to FlutterError.onError callback. This demonstrates how our flutter error integration catches unhandled exceptions.',
              buttonTitle: 'Capture from FlutterError.onError',
            ),
            TooltipButton(
              onPressed: () {
                // Only usable on Flutter >= 3.3
                // and needs the following additional setup:
                // options.addIntegration(OnErrorIntegration());
                (WidgetsBinding.instance.platformDispatcher as dynamic)
                    .onError
                    ?.call(
                      Exception('PlatformDispatcher.onError'),
                      StackTrace.current,
                    );
              },
              text:
                  'This is only usable on Flutter >= 3.3 and requires additional setup: options.addIntegration(OnErrorIntegration());',
              buttonTitle: 'Capture from PlatformDispatcher.onError',
            ),
            TooltipButton(
              onPressed: () => makeWebRequest(context),
              text:
                  'Attaches web request related spans to the transaction and send it to Sentry.',
              buttonTitle: 'Dart: Web request',
            ),
            TooltipButton(
              onPressed: () => makeWebRequestWithDio(context),
              key: const Key('dio_web_request'),
              text:
                  'Attaches web request related spans to the transaction and send it to Sentry.',
              buttonTitle: 'Dio: Web request',
            ),

            TooltipButton(
              onPressed: () => showDialogWithTextAndImage(context),
              text:
                  'Attaches asset bundle related spans to the transaction and send it to Sentry.',
              buttonTitle: 'Flutter: Load assets',
            ),
            TooltipButton(
              onPressed: () {
                // ignore: avoid_print
                print('A print breadcrumb');
                Sentry.captureMessage('A message with a print() Breadcrumb');
              },
              text:
                  'Sends a captureMessage to Sentry with a breadcrumb created by a print() statement.',
              buttonTitle: 'Record print() as breadcrumb',
            ),
            TooltipButton(
              onPressed: () {
                Sentry.captureMessage(
                  'This event has an extra tag',
                  withScope: (scope) {
                    scope.setTag('foo', 'bar');
                  },
                );
              },
              text:
                  'Sends the capture message event with additional Tag to Sentry.',
              buttonTitle: 'Capture message with scope with additional tag',
            ),
            TooltipButton(
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
                // findPrimeNumber(1000000); // Uncomment to see it with profiling
                await transaction.finish(status: const SpanStatus.ok());
              },
              text:
                  'Creates a custom transaction, adds child spans and send them to Sentry.',
              buttonTitle: 'Capture transaction',
            ),
            TooltipButton(
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
              text: 'Sends the capture message with an attachment to Sentry.',
              buttonTitle: 'Capture message with attachment',
            ),
            TooltipButton(
              onPressed: () {
                feedback.BetterFeedback.of(context).show(
                  (feedback.UserFeedback feedback) {
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
                  },
                );
              },
              text:
                  'Sends the capture message with an image attachment to Sentry.',
              buttonTitle: 'Capture message with image attachment',
            ),
            TooltipButton(
              onPressed: () async {
                final id = await Sentry.captureMessage('UserFeedback');
                if (!context.mounted) return;
                await showDialog(
                  context: context,
                  builder: (context) {
                    return UserFeedbackDialog(eventId: id);
                  },
                );
              },
              text:
                  'Shows a custom user feedback dialog without an ongoing event that captures and sends user feedback data to Sentry.',
              buttonTitle: 'Capture User Feedback',
            ),
            TooltipButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) {
                    return UserFeedbackDialog(eventId: SentryId.newId());
                  },
                );
              },
              text: '',
              buttonTitle: 'Show UserFeedback Dialog without event',
            ),
            TooltipButton(
              onPressed: () {
                final log = Logger('Logging');
                log.info('My Logging test');
              },
              text:
                  'Demonstrates the logging integration. log.info() will create an info event send it to Sentry.',
              buttonTitle: 'Logging',
            ),
            TooltipButton(
              onPressed: () async {
                final span = Sentry.getSpan() ??
                    Sentry.startTransaction(
                        'testMetrics', 'span summary example',
                        bindToScope: true);
                Sentry.metrics().increment('increment key',
                    unit: DurationSentryMeasurementUnit.day);
                Sentry.metrics().distribution('distribution key',
                    value: Random().nextDouble() * 10);
                Sentry.metrics().set('set int key',
                    value: Random().nextInt(100),
                    tags: {'myTag': 'myValue', 'myTag2': 'myValue2'});
                Sentry.metrics().set('set string key',
                    stringValue: 'Random n ${Random().nextInt(100)}');
                Sentry.metrics()
                    .gauge('gauge key', value: Random().nextDouble() * 10);
                Sentry.metrics().timing(
                  'timing key',
                  function: () async => await Future.delayed(
                      Duration(milliseconds: Random().nextInt(100)),
                      () => span.finish()),
                  unit: DurationSentryMeasurementUnit.milliSecond,
                );
              },
              text:
                  'Demonstrates the metrics. It creates several metrics and send them to Sentry.',
              buttonTitle: 'Metrics',
            ),
            if (UniversalPlatform.isIOS || UniversalPlatform.isMacOS)
              const CocoaExample(),
            if (UniversalPlatform.isAndroid) const AndroidExample(),
          ].map((widget) {
            if (kIsWeb) {
              // Add vertical padding to web so the tooltip doesn't obstruct the clicking of the button below.
              return Padding(
                padding: const EdgeInsets.only(top: 18.0, bottom: 18.0),
                child: widget,
              );
            }
            return widget;
          }).toList(),
        ),
      ),
    );
  }

  Future<void> isarTest() async {
    final tr = Sentry.startTransaction(
      'isarTest',
      'db',
      bindToScope: true,
    );

    final dir = await getApplicationDocumentsDirectory();

    final isar = await SentryIsar.open(
      [UserSchema],
      directory: dir.path,
    );

    final newUser = User()
      ..name = 'Joe Dirt'
      ..age = 36;

    await isar.writeTxn(() async {
      await isar.users.put(newUser); // insert & update
    });

    final existingUser = await isar.users.get(newUser.id); // get

    await isar.writeTxn(() async {
      await isar.users.delete(existingUser!.id); // delete
    });

    await tr.finish(status: const SpanStatus.ok());
  }

  Future<void> hiveTest() async {
    final tr = Sentry.startTransaction(
      'hiveTest',
      'db',
      bindToScope: true,
    );

    final appDir = await getApplicationDocumentsDirectory();
    SentryHive.init(appDir.path);

    final catsBox = await SentryHive.openBox<Map>('cats');
    await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
    await catsBox.put('loki', {'name': 'Loki', 'age': 2});
    await catsBox.clear();
    await catsBox.close();

    SentryHive.close();

    await tr.finish(status: const SpanStatus.ok());
  }

  Future<void> sqfliteTest() async {
    final tr = Sentry.startTransaction(
      'sqfliteTest',
      'db',
      bindToScope: true,
    );

    // databaseFactory = databaseFactoryFfiWeb; // or databaseFactoryFfi // or SentrySqfliteDatabaseFactory()

    // final sqfDb = await openDatabase(inMemoryDatabasePath);
    final db = await openDatabaseWithSentry(inMemoryDatabasePath);
    // final db = SentryDatabase(sqfDb);
    // final batch = db.batch();
    await db.execute('''
      CREATE TABLE Product (
        id INTEGER PRIMARY KEY,
        title TEXT
      )
  ''');
    final dbTitles = <String>[];
    for (int i = 1; i <= 20; i++) {
      final title = 'Product $i';
      dbTitles.add(title);
      await db.insert('Product', <String, Object?>{'title': title});
    }

    await db.query('Product');

    await db.transaction((txn) async {
      await txn
          .insert('Product', <String, Object?>{'title': 'Product Another one'});
      await txn.delete('Product',
          where: 'title = ?', whereArgs: ['Product Another one']);
    });

    await db.delete('Product', where: 'title = ?', whereArgs: ['Product 1']);

    // final batch = db.batch();
    // batch.delete('Product', where: 'title = ?', whereArgs: dbTitles);
    // await batch.commit();

    await db.close();

    await tr.finish(status: const SpanStatus.ok());
  }

  Future<void> driftTest() async {
    final tr = Sentry.startTransaction(
      'driftTest',
      'db',
      bindToScope: true,
    );

    final executor = SentryQueryExecutor(
      () async => inMemoryExecutor(),
      databaseName: 'sentry_in_memory_db',
    );

    final db = AppDatabase(executor);

    await db.into(db.todoItems).insert(
          TodoItemsCompanion.insert(
            title: 'This is a test thing',
            content: 'test',
          ),
        );

    await db.select(db.todoItems).get();

    await db.close();

    await tr.finish(status: const SpanStatus.ok());
  }
}

extension BuildContextExtension on BuildContext {
  bool get isMounted {
    try {
      return (this as dynamic).mounted;
    } on NoSuchMethodError catch (_) {
      // ignore, only available in newer Flutter versions
    }
    return true;
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
    ]);
  }
}

void navigateToAutoCloseScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: 'AutoCloseScreen'),
      builder: (context) => SentryDisplayWidget(child: const AutoCloseScreen()),
    ),
  );
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

class IntegrationTestWidget extends StatefulWidget {
  const IntegrationTestWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return _IntegrationTestWidgetState();
  }
}

class _IntegrationTestWidgetState extends State<IntegrationTestWidget> {
  _IntegrationTestWidgetState();

  var _output = "--";
  var _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _output,
          key: const Key('output'),
        ),
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: () async => await _captureException(),
                child: const Text('captureException'),
              )
      ],
    );
  }

  Future<void> _captureException() async {
    setState(() {
      _isLoading = true;
    });
    try {
      throw Exception('captureException');
    } catch (error, stackTrace) {
      final id = await Sentry.captureException(error, stackTrace: stackTrace);
      setState(() {
        _output = id.toString();
        _isLoading = false;
      });
    }
  }
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
    failedRequestStatusCodes: [SentryStatusCode.range(400, 500)],
  );
  // We don't do any exception handling here.
  // In case of an exception, let it get caught and reported to Sentry
  final response = await client.get(Uri.parse(exampleUrl));

  await transaction.finish(status: const SpanStatus.ok());

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
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
  dio.addSentry();

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
    response = await dio.get<String>(exampleUrl);
    span.status = const SpanStatus.ok();
  } catch (exception, stackTrace) {
    span.throwable = exception;
    span.status = const SpanStatus.internalError();
    await Sentry.captureException(exception, stackTrace: stackTrace);
  } finally {
    await span.finish();
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
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

  if (!context.mounted) return;
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

  void updatePrimaryColor(MaterialColor color) {
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

// Don't inline this one or it shows up as an anonymous closure in profiles.
@pragma("vm:never-inline")
int findPrimeNumber(int n) {
  int count = 0;
  int a = 2;
  while (count < n) {
    int b = 2;
    bool prime = true; // to check if found a prime
    while (b * b <= a) {
      if (a % b == 0) {
        prime = false;
        break;
      }
      b++;
    }
    if (prime) {
      count++;
    }
    a++;
  }
  return a - 1;
}
