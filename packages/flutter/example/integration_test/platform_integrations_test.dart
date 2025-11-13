// ignore_for_file: invalid_use_of_internal_member, depend_on_referenced_packages

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry/src/dart_exception_type_identifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/flutter_exception_type_identifier.dart';
import 'utils.dart';

SentryFlutterOptions _currentOptions() =>
    Sentry.currentHub.options as SentryFlutterOptions;

List<String> _integrationNames(SentryFlutterOptions options) =>
    options.integrations.map((i) => i.runtimeType.toString()).toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Sentry.close();
  });

  group('Platform integrations (non-web)', () {
    group('Common integrations', () {
      testWidgets('platform-agnostic integrations are present', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final names = _integrationNames(options);

        expect(names.contains('WidgetsFlutterBindingIntegration'), isTrue);
        expect(names.contains('FlutterErrorIntegration'), isTrue);
        expect(names.contains('LoadReleaseIntegration'), isTrue);
        expect(names.contains('DebugPrintIntegration'), isTrue);
        expect(names.contains('SentryViewHierarchyIntegration'), isTrue);
      });
    });

    group('Defaults', () {
      testWidgets('debug and sdk name', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        expect(options.debug, isTrue);
        expect(options.sdk.name, 'sentry.dart.flutter');
      });
    });

    group('Scope and native binding', () {
      testWidgets('scope sync and NativeScopeObserver', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        expect(options.enableScopeSync, isTrue);
        final hasNativeScopeObserver = options.scopeObservers
            .any((o) => o.runtimeType.toString() == 'NativeScopeObserver');
        expect(hasNativeScopeObserver, isTrue);
      });

      testWidgets('native binding available', (tester) async {
        if (kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});
        expect(SentryFlutter.native, isNotNull);
      });
    });

    group('Integrations', () {
      testWidgets('core native integrations are present (non-web)',
          (tester) async {
        if (kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final names = _integrationNames(options);

        // Core native-related
        expect(names.contains('NativeSdkIntegration'), isTrue);
        expect(names.contains('LoadNativeDebugImagesIntegration'), isTrue);
      });

      testWidgets('platform-specific integrations by platform', (tester) async {
        if (kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
          // Ensure replay integrations are added where supported
          o.replay.sessionSampleRate = 1.0;
          o.replay.onErrorSampleRate = 1.0;
        }, appRunner: () async {});

        final options = _currentOptions();
        final names = _integrationNames(options);

        final isAndroid =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final isMacOS =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

        if (isAndroid) {
          expect(names.contains('LoadContextsIntegration'), isTrue);
          expect(names.contains('ReplayIntegration'), isTrue);
          expect(names.contains('ReplayLogIntegration'), isTrue);
        } else if (isIOS) {
          expect(names.contains('LoadContextsIntegration'), isTrue);
          expect(names.contains('ReplayIntegration'), isTrue);
          expect(names.contains('ReplayLogIntegration'), isTrue);
        } else if (isMacOS) {
          expect(names.contains('LoadContextsIntegration'), isTrue);
          // Replay not supported on macOS by default
          // TODO: this is a minor bug, the integration should not be added for macOS
          // it does not do anything because 'call' is gated behind a flag but we should
          // still not add it
          expect(names.contains('ReplayIntegration'), isTrue);
          expect(names.contains('ReplayLogIntegration'), isFalse);
        }
      });

      testWidgets('ordering: WidgetsBinding before OnErrorIntegration',
          (tester) async {
        if (kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final names = _integrationNames(options);

        final widgetsIdx = names.indexOf('WidgetsFlutterBindingIntegration');
        final onErrorIdx = names.indexOf('OnErrorIntegration');
        expect(widgetsIdx, greaterThanOrEqualTo(0));
        expect(onErrorIdx, greaterThanOrEqualTo(0));
        expect(widgetsIdx < onErrorIdx, isTrue);
      });

      testWidgets('web integrations and ordering', (tester) async {
        if (!kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final names = _integrationNames(options);

        // Web-specific integrations
        expect(names.contains('ConnectivityIntegration'), isTrue);
        expect(names.contains('WebSessionIntegration'), isTrue);
        expect(names.contains('GenericAppStartIntegration'), isTrue);

        // Should not be present on web
        expect(names.contains('OnErrorIntegration'), isFalse);
        expect(names.contains('ThreadInfoIntegration'), isFalse);
        expect(names.contains('LoadContextsIntegration'), isFalse);
        expect(names.contains('ReplayIntegration'), isFalse);
        expect(names.contains('ReplayLogIntegration'), isFalse);

        // Ordering: RunZonedGuarded before Widgets
        final runZonedIdx = names.indexOf('RunZonedGuardedIntegration');
        final widgetsIdx = names.indexOf('WidgetsFlutterBindingIntegration');
        expect(runZonedIdx, greaterThanOrEqualTo(0));
        expect(widgetsIdx, greaterThanOrEqualTo(0));
        expect(runZonedIdx < widgetsIdx, isTrue);
      });
    });

    group('Event processors', () {
      testWidgets('FlutterEnricher precedes LoadContexts', (tester) async {
        if (kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final isAndroid =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final isMacOS =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
        if (isAndroid || isIOS || isMacOS) {
          final processors = options.eventProcessors;
          final enricherIndex = processors.indexWhere((p) =>
              p.runtimeType.toString() == 'FlutterEnricherEventProcessor');
          final loadContextsIndex = processors.indexWhere((p) =>
              p.runtimeType.toString() ==
              '_LoadContextsIntegrationEventProcessor');
          expect(enricherIndex, greaterThanOrEqualTo(0));
          expect(loadContextsIndex, greaterThanOrEqualTo(0));
          expect(enricherIndex, lessThan(loadContextsIndex));
        }
      });
    });

    group('Transport', () {
      testWidgets('transport per platform', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final transportType = options.transport.runtimeType.toString();
        expect(transportType, 'ClientReportTransport');
        // Access innerTransport via dynamic to avoid importing platform types.
        final dynamic dynTransport = options.transport;
        final innerType = dynTransport.innerTransport.runtimeType.toString();
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
        final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
        if (kIsWeb) {
          expect(innerType, 'JavascriptTransport');
        } else if (isAndroid || isIOS || isMacOS) {
          expect(innerType, 'FileSystemTransport');
        } else {
          expect(innerType, 'HttpTransport');
        }
      });
    });

    group('Profiling', () {
      testWidgets('profiler factory per platform', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
          o.profilesSampleRate = 1.0;
        }, appRunner: () async {});

        if (kIsWeb) {
          expect(Sentry.currentHub.profilerFactory, isNull);
        } else {
          final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
          final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
          if (isIOS || isMacOS) {
            final factoryType =
                Sentry.currentHub.profilerFactory?.runtimeType.toString();
            expect(factoryType, 'SentryNativeProfilerFactory');
          } else {
            expect(Sentry.currentHub.profilerFactory, isNull);
          }
        }
      });
    });

    group('Threading', () {
      testWidgets('ThreadInfoIntegration present', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final hasThreadInfo = options.integrations.any((integration) =>
            integration.runtimeType.toString() == 'ThreadInfoIntegration');
        if (kIsWeb) {
          expect(hasThreadInfo, isFalse);
        } else {
          expect(hasThreadInfo, isTrue);
        }
      });
    });

    group('Symbolication', () {
      testWidgets('Dart symbolication disabled when native present',
          (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.debug = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        if (SentryFlutter.native != null) {
          expect(options.enableDartSymbolication, isFalse);
        }
      });
    });

    group('Exception identifiers', () {
      testWidgets('Flutter first then Dart', (tester) async {
        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
        }, appRunner: () async {});

        final options = _currentOptions();
        expect(
            options.exceptionTypeIdentifiers.length, greaterThanOrEqualTo(2));

        expect(
          options.exceptionTypeIdentifiers.first,
          isA<CachingExceptionTypeIdentifier>().having(
            (c) => c.identifier,
            'wrapped identifier',
            isA<FlutterExceptionTypeIdentifier>(),
          ),
        );
        expect(
          options.exceptionTypeIdentifiers[1],
          isA<CachingExceptionTypeIdentifier>().having(
            (c) => c.identifier,
            'wrapped identifier',
            isA<DartExceptionTypeIdentifier>(),
          ),
        );
      });
    });

    group('Screenshot integration', () {
      testWidgets('added when enabled', (tester) async {
        if (kIsWeb) return;

        await SentryFlutter.init((o) {
          o.dsn = fakeDsn;
          o.attachScreenshot = true;
        }, appRunner: () async {});

        final options = _currentOptions();
        final hasScreenshotIntegration = options.integrations.any(
            (integration) =>
                integration.runtimeType.toString() == 'ScreenshotIntegration');
        expect(hasScreenshotIntegration, isTrue);
      });
    });
  });
}
