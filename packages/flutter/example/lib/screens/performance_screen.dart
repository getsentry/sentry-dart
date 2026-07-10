// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_drift/sentry_drift.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:sentry_isar/sentry_isar.dart';
import 'package:sentry_sqflite/sentry_sqflite.dart';
import 'package:sqflite/sqflite.dart';
import 'package:universal_platform/universal_platform.dart';

import '../app_config.dart';
import '../auto_close_screen.dart';
import '../drift/connection/connection.dart';
import '../drift/database.dart';
import '../isar/user.dart';
import '../widgets.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: SingleChildScrollView(
        child: Center(
          child: IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  TooltipButton(
                    onPressed: () => navigateToAutoCloseScreen(context),
                    text:
                        'Pushes a screen and creates a transaction named \'AutoCloseScreen\' with a child span that finishes after 3 seconds. \nAfter the screen has popped the transaction can then be seen on the performance page.',
                    buttonTitle: 'Route Navigation Observer',
                  ),
                  if (!UniversalPlatform.isWeb)
                    const TooltipButton(
                      onPressed: driftTest,
                      text:
                          'Executes CRUD operations on an in-memory with Drift and sends the created transaction to Sentry.',
                      buttonTitle: 'drift',
                    ),
                  if (!UniversalPlatform.isWeb)
                    const TooltipButton(
                      onPressed: hiveTest,
                      text:
                          'Executes CRUD operations on an in-memory with Hive and sends the created transaction to Sentry.',
                      buttonTitle: 'hive',
                    ),
                  if (!UniversalPlatform.isWeb)
                    const TooltipButton(
                      onPressed: isarTest,
                      text:
                          'Executes CRUD operations on an in-memory with Isar and sends the created transaction to Sentry.',
                      buttonTitle: 'isar',
                    ),
                  const TooltipButton(
                    onPressed: sqfliteTest,
                    text:
                        'Executes CRUD operations on an in-memory with sqflite and sends the created transaction to Sentry.',
                    buttonTitle: 'sqflite',
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
                    onPressed: () => makeWebRequestWithNetworkDetails(context),
                    key: const Key('web_request_network_details'),
                    text:
                        'Enables enableReplayNetworkDetailsCapturing for this request and shows the captured '
                        'request/response headers and body that get attached to the http breadcrumb for '
                        'Session Replay.',
                    buttonTitle: 'Dart: Web request with network details',
                  ),
                  TooltipButton(
                    onPressed: () => showDialogWithTextAndImage(context),
                    text:
                        'Attaches asset bundle related spans to the transaction and send it to Sentry.',
                    buttonTitle: 'Flutter: Load assets',
                  ),
                  TooltipButton(
                    onPressed: () async {
                      if (Sentry.currentHub.options.traceLifecycle ==
                          SentryTraceLifecycle.stream) {
                        await Sentry.startSpan(
                          'myNewSpanWithChildren',
                          (rootSpan) async {
                            rootSpan.setAttribute(
                                'myTag', SentryAttribute.string('myValue'));
                            rootSpan.setAttribute('myExtra',
                                SentryAttribute.string('myExtraValue'));

                            await Future.delayed(
                                const Duration(milliseconds: 50));

                            await Sentry.startSpan('childOfMyOp',
                                (childSpan) async {
                              childSpan.setAttribute('myNewTag',
                                  SentryAttribute.string('myNewValue'));
                              childSpan.setAttribute('myNewData',
                                  SentryAttribute.string('myNewDataValue'));

                              await Future.delayed(
                                  const Duration(milliseconds: 70));

                              await Sentry.startSpan('childOfChildOfMyOp',
                                  (nestedSpan) async {
                                await Future.delayed(
                                    const Duration(milliseconds: 110));
                              });
                            });

                            await Future.delayed(
                                const Duration(milliseconds: 50));
                          },
                        );
                      } else {
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

                        await span.finish(
                            status: const SpanStatus.resourceExhausted());

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
                      }
                    },
                    text:
                        'Creates a custom transaction or nested spans and sends them to Sentry.',
                    buttonTitle: 'Capture transaction / spans',
                  ),
                  if (Sentry.currentHub.options.traceLifecycle ==
                      SentryTraceLifecycle.stream)
                    TooltipButton(
                      onPressed: () => spanV2Demo(),
                      text:
                          'Demonstrates the new SpanV2 API with streaming trace lifecycle. Creates spans and sets attributes.',
                      buttonTitle: 'Emit SpanV2',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void navigateToAutoCloseScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: 'AutoCloseScreen'),
      // ignore: deprecated_member_use
      builder: (context) => const SentryDisplayWidget(
        child: AutoCloseScreen(),
      ),
    ),
  );
}

Future<void> isarTest() async {
  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('isarTest', (span) async {
      await _runIsarOperations();
    });
  } else {
    final tr = Sentry.startTransaction('isarTest', 'db', bindToScope: true);
    await _runIsarOperations();
    await tr.finish(status: const SpanStatus.ok());
  }
}

Future<void> _runIsarOperations() async {
  final dir = await getApplicationDocumentsDirectory();
  final isar = await SentryIsar.open([UserSchema], directory: dir.path);
  final newUser = User()
    ..name = 'Joe Dirt'
    ..age = 36;
  await isar.writeTxn(() async {
    await isar.users.put(newUser);
  });
  final existingUser = await isar.users.get(newUser.id);
  await isar.writeTxn(() async {
    await isar.users.delete(existingUser!.id);
  });
}

Future<void> hiveTest() async {
  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('hiveTest', (span) async {
      await _runHiveOperations();
    });
  } else {
    final tr = Sentry.startTransaction('hiveTest', 'db', bindToScope: true);
    await _runHiveOperations();
    await tr.finish(status: const SpanStatus.ok());
  }
}

Future<void> _runHiveOperations() async {
  final appDir = await getApplicationDocumentsDirectory();
  SentryHive.init(appDir.path);
  final catsBox = await SentryHive.openBox<Map>('cats');
  await catsBox.put('fluffy', {'name': 'Fluffy', 'age': 4});
  await catsBox.put('loki', {'name': 'Loki', 'age': 2});
  await catsBox.clear();
  await catsBox.close();
  SentryHive.close();
}

Future<void> sqfliteTest() async {
  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('sqfliteTest', (span) async {
      await _runSqfliteOperations();
    });
  } else {
    final tr = Sentry.startTransaction('sqfliteTest', 'db', bindToScope: true);
    await _runSqfliteOperations();
    await tr.finish(status: const SpanStatus.ok());
  }
}

Future<void> _runSqfliteOperations() async {
  final db = await openDatabaseWithSentry(inMemoryDatabasePath);
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
  await db.close();
}

Future<void> driftTest() async {
  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('driftTest', (span) async {
      await _runDriftOperations();
    });
  } else {
    final tr = Sentry.startTransaction('driftTest', 'db', bindToScope: true);
    await _runDriftOperations();
    await tr.finish(status: const SpanStatus.ok());
  }
}

Future<void> _runDriftOperations() async {
  final executor = inMemoryExecutor().interceptWith(
      SentryQueryInterceptor(databaseName: 'sentry_in_memory_db'));
  final db = AppDatabase(executor);
  await db.into(db.todoItems).insert(
        TodoItemsCompanion.insert(
          title: 'This is a test thing',
          content: 'test',
        ),
      );
  await db.select(db.todoItems).get();
  await db.close();
}

Future<void> makeWebRequest(BuildContext context) async {
  final client = SentryHttpClient(
    failedRequestStatusCodes: [SentryStatusCode.range(400, 500)],
  );

  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('flutterwebrequest', (span) async {
      final response = await client.get(Uri.parse(exampleUrl));
      if (!context.mounted) return;
      await _showWebResponseDialog(context, response.statusCode, response.body);
    });
  } else {
    final transaction = Sentry.getSpan() ??
        Sentry.startTransaction(
          'flutterwebrequest',
          'request',
          bindToScope: true,
        );
    final response = await client.get(Uri.parse(exampleUrl));
    await transaction.finish(status: const SpanStatus.ok());
    if (!context.mounted) return;
    await _showWebResponseDialog(context, response.statusCode, response.body);
  }
}

Future<void> _showWebResponseDialog(
    BuildContext context, int? statusCode, String body) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Response $statusCode'),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> makeWebRequestWithDio(BuildContext context) async {
  final dio = Dio();
  dio.addSentry();

  Response<String>? response;

  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('dio-web-request', (span) async {
      try {
        response = await dio.get<String>(exampleUrl);
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
      }
    });
  } else {
    final transaction = Sentry.getSpan() ??
        Sentry.startTransaction(
          'dio-web-request',
          'request',
          bindToScope: true,
        );
    final span = transaction.startChild('dio', description: 'desc');
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
  }

  if (!context.mounted) return;
  await _showDioResponseDialog(context, response);
}

Future<void> _showDioResponseDialog(
    BuildContext context, Response<String>? response) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Response ${response?.statusCode}'),
        content: SingleChildScrollView(
            child: Text(response?.data ?? 'failed request')),
        actions: [
          MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> makeWebRequestWithNetworkDetails(BuildContext context) async {
  // enableReplayNetworkDetailsCapturing, networkDetailAllowUrls and
  // networkRequestHeaders are configured in main.dart at SentryFlutter.init()
  // time - the native replay integration only reads them once, at startup.
  final client = SentryHttpClient();
  await client.post(
    Uri.parse(exampleUrl),
    headers: {
      'foo': 'bar',
      'content-type': 'application/json',
    },
    body: jsonEncode({
      'credit_card': 'true',
      'id': '0000-0000-0000-0000',
    }),
  );

  Breadcrumb? httpBreadcrumb;
  await Sentry.configureScope((scope) {
    httpBreadcrumb = scope.breadcrumbs
        .where((breadcrumb) => breadcrumb.category == 'http')
        .lastOrNull;
  });

  if (!context.mounted) return;
  await _showNetworkDetailsDialog(context, httpBreadcrumb);
}

Future<void> _showNetworkDetailsDialog(
    BuildContext context, Breadcrumb? breadcrumb) async {
  const encoder = JsonEncoder.withIndent('  ');
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Captured http breadcrumb'),
        content: SingleChildScrollView(
          child: Text(encoder.convert(breadcrumb?.data ?? {})),
        ),
        actions: [
          MaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> showDialogWithTextAndImage(BuildContext context) async {
  Future<void> loadAndShowAssets() async {
    final text = await DefaultAssetBundle.of(context)
        .loadString('assets/lorem-ipsum.txt');

    if (!context.mounted) return;
    final imageBytes =
        await DefaultAssetBundle.of(context).load('assets/sentry-wordmark.png');
    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      routeSettings: const RouteSettings(name: 'AssetBundle dialog'),
      builder: (context) {
        return AlertDialog(
          title: const Text('Asset Example'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/sentry-wordmark.png'),
                Image.asset('assets/sentry-wordmark.png', bundle: rootBundle),
                Image.asset('assets/sentry-wordmark.png',
                    bundle: DefaultAssetBundle.of(context)),
                Image.network(
                    'https://www.gstatic.com/recaptcha/api2/logo_48.png'),
                Image.memory(imageBytes.buffer.asUint8List()),
                Text(text),
              ],
            ),
          ),
          actions: [
            MaterialButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  if (Sentry.currentHub.options.traceLifecycle == SentryTraceLifecycle.stream) {
    await Sentry.startSpan('asset-bundle-load', (span) async {
      await loadAndShowAssets();
    });
  } else {
    final transaction = Sentry.getSpan() ??
        Sentry.startTransaction(
          'asset-bundle-transaction',
          'load',
          bindToScope: true,
        );
    await loadAndShowAssets();
    await transaction.finish(status: const SpanStatus.ok());
  }
}

Future<void> spanV2Demo() async {
  await Sentry.startSpan('span1 test', (_) async {
    await Sentry.startSpan('ignoreSpan1', (_) async {
      await Sentry.startSpan('ignoreSpan2', (_) async {
        await Sentry.startSpan('deep child', (_) async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
      });
    });
    await Sentry.startSpan('span1 child1', (_) async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await Sentry.startSpan('span1 child2', (_) async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });

  await Sentry.startSpan('span2 test', (_) async {
    await Sentry.startSpan('span2 child1', (_) async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await Sentry.startSpan('span2 child2', (_) async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });

  final syncResult =
      Sentry.startSpanSync('span3 sync function', (_) => 'sync works!');
  // ignore: avoid_print
  print('span3 sync function result: $syncResult');

  await Sentry.startSpan(
    'spanv2-demo-root',
    (rootSpan) async {
      rootSpan.setAttributes({
        'demo.type': SentryAttribute.string('comprehensive'),
        'demo.version': SentryAttribute.int(2),
      });
      rootSpan.setAttribute(
          'root.custom', SentryAttribute.string('root-value'));

      await Future.delayed(const Duration(milliseconds: 50));

      await Sentry.startSpan('spanv2-demo-child', (childSpan) async {
        childSpan.setAttributes({
          'child.operation': SentryAttribute.string('database-query'),
          'child.rows': SentryAttribute.int(42),
        });

        await Future.delayed(const Duration(milliseconds: 30));

        await Sentry.startSpan('spanv2-demo-nested', (nestedSpan) async {
          nestedSpan.setAttribute('nested.level', SentryAttribute.int(2));
          await Future.delayed(const Duration(milliseconds: 20));
        });
      });
    },
    attributes: {
      'demo.source': SentryAttribute.string('example-app'),
    },
  );
}
