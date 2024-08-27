import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';

import 'multi_view_app.dart';

const String exampleDsn =
    'https://e85b375ffb9f43cf8bdf9787768149e0@o447951.ingest.sentry.io/5428562';

/// This is an exampleUrl that will be used to demonstrate how http requests are captured.
const String exampleUrl = 'https://jsonplaceholder.typicode.com/todos/';

var _isIntegrationTest = false;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  await setupSentry(
    () => runWidget(
      SentryWidget(
        child: DefaultAssetBundle(
          bundle: SentryAssetBundle(),
          child: MultiViewApp(
            viewBuilder: (BuildContext context) => const MyApp(),
          ),
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
      options.addInAppInclude('sentry_flutter_multiview_example');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(
          title: 'Flutter Demo Home Page ${View.of(context).viewId}'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
