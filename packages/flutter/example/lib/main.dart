// ignore_for_file: library_private_types_in_public_api, invalid_use_of_internal_member, experimental_member_use

import 'dart:async';
import 'dart:convert';

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

const _traceLifecycleName = String.fromEnvironment(
  'SENTRY_TRACE_LIFECYCLE',
  defaultValue: 'stream',
);
const _transactionItemType = 'transaction';
const _spanItemType = 'span';

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
      options.traceLifecycle = switch (_traceLifecycleName) {
        'static' => SentryTraceLifecycle.static,
        'stream' => SentryTraceLifecycle.stream,
        _ => throw ArgumentError.value(
            _traceLifecycleName,
            'SENTRY_TRACE_LIFECYCLE',
            'Expected static or stream',
          ),
      };
      options.enableStandaloneAppStartTracing = true;

      options.replay.sessionSampleRate = 0.0;
      options.replay.onErrorSampleRate = 0.0;

      options.transport = _StandaloneAppStartDebugTransport(
        options.transport,
        _traceLifecycleName,
      );

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

final class _StandaloneAppStartDebugTransport implements Transport {
  _StandaloneAppStartDebugTransport(this._delegate, this._traceLifecycle);

  final Transport _delegate;
  final String _traceLifecycle;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    try {
      for (final item in envelope.items) {
        final dataResult = item.dataFactory();
        final data =
            dataResult is Future<List<int>> ? await dataResult : dataResult;
        final itemHeader = await item.header.toJson(data.length);
        final itemType = itemHeader['type'];
        if (itemType != _transactionItemType && itemType != _spanItemType) {
          continue;
        }

        final payload = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        final summary = switch (itemType) {
          _transactionItemType => _staticSummary(itemHeader, payload),
          _spanItemType => _streamSummary(itemHeader, payload),
          _ => null,
        };
        if (summary != null) {
          _debugLog(jsonEncode(summary));
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to inspect standalone app-start envelope: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return _delegate.send(envelope);
  }

  Map<String, dynamic>? _staticSummary(
    Map<String, dynamic> itemHeader,
    Map<String, dynamic> payload,
  ) {
    if (payload['transaction'] != 'App Start') return null;

    final contexts = payload['contexts'] as Map<String, dynamic>?;
    final spans = payload['spans'] as List<dynamic>? ?? const [];
    return {
      'trace_lifecycle': _traceLifecycle,
      'envelope_item': itemHeader,
      'payload': {
        ..._select(payload, const [
          'type',
          'transaction',
          'start_timestamp',
          'timestamp',
          'measurements',
          'transaction_info',
        ]),
        'trace_context': contexts?['trace'],
        'spans': spans
            .whereType<Map<String, dynamic>>()
            .map(_staticSpanSummary)
            .toList(),
      },
    };
  }

  Map<String, dynamic>? _streamSummary(
    Map<String, dynamic> itemHeader,
    Map<String, dynamic> payload,
  ) {
    final spans = (payload['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (!spans.any((span) => span['name'] == 'App Start')) return null;

    return {
      'trace_lifecycle': _traceLifecycle,
      'envelope_item': itemHeader,
      'payload': {
        ..._select(payload, const ['version', 'ingest_settings']),
        'items': spans.map(_streamSpanSummary).toList(),
      },
    };
  }

  Map<String, dynamic> _staticSpanSummary(Map<String, dynamic> span) =>
      _select(span, const [
        'trace_id',
        'span_id',
        'parent_span_id',
        'op',
        'description',
        'origin',
        'start_timestamp',
        'timestamp',
        'status',
      ]);

  Map<String, dynamic> _streamSpanSummary(Map<String, dynamic> span) {
    final attributes = span['attributes'] as Map<String, dynamic>? ?? const {};
    return {
      ..._select(span, const [
        'trace_id',
        'span_id',
        'parent_span_id',
        'is_segment',
        'name',
        'status',
        'start_timestamp',
        'end_timestamp',
      ]),
      'attributes': _select(attributes, const [
        'sentry.op',
        'sentry.origin',
        'sentry.segment.name',
        'sentry.segment.id',
        'sentry.transaction',
        'app.vitals.start.type',
        'app.vitals.start.screen',
        'app.vitals.start.value',
        'app.vitals.start.cold.value',
        'app.vitals.start.warm.value',
      ]),
    };
  }

  Map<String, dynamic> _select(
    Map<String, dynamic> source,
    List<String> keys,
  ) =>
      {
        for (final key in keys)
          if (source.containsKey(key)) key: source[key],
      };

  void _debugLog(String message) {
    const chunkSize = 700;
    final chunkCount = (message.length / chunkSize).ceil();
    for (var index = 0; index < chunkCount; index++) {
      final start = index * chunkSize;
      final end = (start + chunkSize).clamp(0, message.length);
      debugPrintSynchronously(
        'STANDALONE_APP_START_SENT[$_traceLifecycle] '
        '${index + 1}/$chunkCount ${message.substring(start, end)}',
        wrapWidth: null,
      );
    }
  }
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
