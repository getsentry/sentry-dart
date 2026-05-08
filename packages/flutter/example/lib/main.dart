// ignore_for_file: library_private_types_in_public_api, invalid_use_of_internal_member, experimental_member_use

import 'dart:async';

import 'package:feedback/feedback.dart' as feedback;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';

import 'app_config.dart' as config;
import 'home_screen.dart';
import 'theme_provider.dart';

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
    config.exampleDsn,
  );
}

Future<void> setupSentryWithCustomInit(
    AppRunner appRunner, OptionsConfiguration optionsConfiguration) async {
  return SentryFlutter.init(optionsConfiguration, appRunner: appRunner);
}

Future<void> setupSentry(
  AppRunner appRunner,
  String dsn, {
  bool isIntegrationTest = false,
  BeforeSendCallback? beforeSendCallback,
}) async {
  await SentryFlutter.init(
    (options) {
      options.dsn = config.exampleDsn;
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
      options.attachViewHierarchy = true;
      // We can enable Sentry debug logging during development. This is likely
      // going to log too much for your app, but can be useful when figuring out
      // configuration issues, e.g. finding out why your events are not uploaded.
      options.diagnosticLevel = SentryLevel.debug;
      options.debug = kDebugMode;
      options.spotlight = Spotlight(enabled: true);
      options.enableTimeToFullDisplayTracing = true;
      options.maxRequestBodySize = MaxRequestBodySize.always;
      options.navigatorKey = config.navigatorKey;
      options.traceLifecycle = SentryTraceLifecycle.stream;

      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;

      options.enableLogs = true;

      options.beforeSendMetric = (metric) {
        if (metric.name == 'drop-metric') {
          return null;
        }
        return metric;
      };

      options.ignoreSpans = [
        IgnoreSpanRule.nameContains('ignore'),
        IgnoreSpanRule.nameContains('ignoreSpan1'),
        IgnoreSpanRule.nameContains('ignoreSpan2'),
        IgnoreSpanRule.nameContains('Open DB'),
      ];

      // Example: Scrub sensitive data from spans before sending
      options.beforeSendSpan = (span) {
        final sensitiveAttributes = span.attributes.entries
            .where((entry) =>
                entry.value.value is String &&
                entry.value.value.contains('secret'))
            .toList();
        for (final attribute in sensitiveAttributes) {
          span.removeAttribute(attribute.key);
        }
      };

      config.isIntegrationTest = isIntegrationTest;
      if (config.isIntegrationTest) {
        options.dist = '1';
        options.environment = 'integration';
        options.beforeSend = beforeSendCallback;
      }
    },
    appRunner: appRunner,
  );

  Sentry.configureScope((scope) {
    final user = SentryUser(
      id: SentryId.newId().toString(),
      name: 'J. Smith',
      email: 'j.smith@example.com',
    );
    scope.setUser(user);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    doWork();
  }

  void doWork() async {
    final rootDisplay = SentryFlutter.currentDisplay();

    await Sentry.startSpan('Custom span that runs during app start', (_) async {
      await Future.delayed(const Duration(seconds: 1));
    });

    rootDisplay?.reportFullyDisplayed();
  }

  @override
  Widget build(BuildContext context) {
    return feedback.BetterFeedback(
      child: ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorKey: config.navigatorKey,
            navigatorObservers: [
              SentryNavigatorObserver(),
            ],
            theme: Provider.of<ThemeProvider>(context).theme,
            home: const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
