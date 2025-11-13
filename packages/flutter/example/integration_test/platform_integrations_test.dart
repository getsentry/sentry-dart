// ignore_for_file: invalid_use_of_internal_member, depend_on_referenced_packages

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry/src/dart_exception_type_identifier.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/flutter_exception_type_identifier.dart';
import 'package:sentry_flutter/src/event_processor/flutter_enricher_event_processor.dart';
import 'package:sentry_flutter/src/integrations/connectivity/connectivity_integration.dart';
import 'package:sentry_flutter/src/integrations/debug_print_integration.dart';
import 'package:sentry_flutter/src/integrations/flutter_error_integration.dart';
import 'package:sentry_flutter/src/integrations/generic_app_start_integration.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';
import 'package:sentry_flutter/src/integrations/native_load_debug_images_integration.dart';
import 'package:sentry_flutter/src/integrations/native_sdk_integration.dart';
import 'package:sentry_flutter/src/integrations/replay_log_integration.dart';
import 'package:sentry_flutter/src/integrations/screenshot_integration.dart';
import 'package:sentry_flutter/src/integrations/thread_info_integration.dart';
import 'package:sentry_flutter/src/integrations/web_session_integration.dart';
import 'package:sentry_flutter/src/integrations/widgets_flutter_binding_integration.dart';
import 'package:sentry_flutter/src/replay/integration.dart';
import 'package:sentry_flutter/src/view_hierarchy/view_hierarchy_integration.dart';
import 'package:sentry/src/transport/client_report_transport.dart';
import 'package:sentry/src/transport/http_transport.dart';
import 'package:sentry_flutter/src/file_system_transport.dart';
import 'package:sentry_flutter/src/web/javascript_transport.dart';
import 'utils.dart';

SentryFlutterOptions _currentOptions() =>
    Sentry.currentHub.options as SentryFlutterOptions;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Sentry.close();
  });

  group('SentryFlutter', () {
    group('Common integrations (all platforms)', () {
      testWidgets('adds platform-agnostic integrations', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        expect(
            options.integrations
                .any((i) => i is WidgetsFlutterBindingIntegration),
            isTrue);
        expect(options.integrations.any((i) => i is FlutterErrorIntegration),
            isTrue);
        expect(options.integrations.any((i) => i is LoadReleaseIntegration),
            isTrue);
        expect(options.integrations.any((i) => i is DebugPrintIntegration),
            isTrue);
        expect(
            options.integrations
                .any((i) => i is SentryViewHierarchyIntegration),
            isTrue);
      });
    });

    group('Initialization defaults', () {
      testWidgets('enables debug and sets Flutter SDK name', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        expect(options.debug, isTrue);
        expect(options.sdk.name, 'sentry.dart.flutter');
      });
    });

    group('Scope sync and native bridge', () {
      testWidgets('enables scope sync and adds NativeScopeObserver',
          (tester) async {
        if (kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        expect(options.enableScopeSync, isTrue);
        final hasNativeScopeObserver = options.scopeObservers
            .any((o) => o.runtimeType.toString() == 'NativeScopeObserver');
        expect(hasNativeScopeObserver, isTrue);
      });

      testWidgets('exposes SentryFlutter.native', (tester) async {
        if (kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        expect(SentryFlutter.native, isNotNull);
      });
    });

    group('Integration registration', () {
      testWidgets('adds core native integrations (Native SDK, DebugImages)',
          (tester) async {
        if (kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        // Core native-related
        expect(
            options.integrations.any((i) => i is NativeSdkIntegration), isTrue);
        expect(
            options.integrations
                .any((i) => i is LoadNativeDebugImagesIntegration),
            isTrue);
      });

      testWidgets('adds platform-specific integrations (LoadContexts, Replay)',
          (tester) async {
        if (kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
            // Ensure replay integrations are added where supported
            o.replay.sessionSampleRate = 1.0;
            o.replay.onErrorSampleRate = 1.0;
          }, appRunner: () async {});
        });

        final options = _currentOptions();

        final isAndroid =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final isMacOS =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

        if (isAndroid) {
          expect(options.integrations.any((i) => i is LoadContextsIntegration),
              isTrue);
          expect(
              options.integrations.any((i) => i is ReplayIntegration), isTrue);
          expect(options.integrations.any((i) => i is ReplayLogIntegration),
              isTrue);
        } else if (isIOS) {
          expect(options.integrations.any((i) => i is LoadContextsIntegration),
              isTrue);
          expect(
              options.integrations.any((i) => i is ReplayIntegration), isTrue);
          expect(options.integrations.any((i) => i is ReplayLogIntegration),
              isTrue);
        } else if (isMacOS) {
          expect(options.integrations.any((i) => i is LoadContextsIntegration),
              isTrue);
          // Replay not supported on macOS by default
          // TODO: this is a minor bug, the integration should not be added for macOS
          // it does not do anything because 'call' is gated behind a flag but we should
          // still not add it
          expect(
              options.integrations.any((i) => i is ReplayIntegration), isTrue);
          expect(options.integrations.any((i) => i is ReplayLogIntegration),
              isFalse);
        }
      });

      testWidgets('registers WidgetsBinding before OnError', (tester) async {
        if (kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        final widgetsIdx = options.integrations
            .indexWhere((i) => i is WidgetsFlutterBindingIntegration);
        final onErrorIdx =
            options.integrations.indexWhere((i) => i is OnErrorIntegration);
        expect(widgetsIdx, greaterThanOrEqualTo(0));
        expect(onErrorIdx, greaterThanOrEqualTo(0));
        expect(widgetsIdx < onErrorIdx, isTrue);
      });

      testWidgets(
          'adds web integrations and orders RunZonedGuarded before Widgets',
          (tester) async {
        if (!kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        // Web-specific integrations
        expect(options.integrations.any((i) => i is ConnectivityIntegration),
            isTrue);
        expect(options.integrations.any((i) => i is WebSessionIntegration),
            isTrue);
        expect(options.integrations.any((i) => i is GenericAppStartIntegration),
            isTrue);

        // Should not be present on web
        expect(
            options.integrations.any((i) => i is OnErrorIntegration), isFalse);
        expect(options.integrations.any((i) => i is ThreadInfoIntegration),
            isFalse);
        expect(options.integrations.any((i) => i is LoadContextsIntegration),
            isFalse);
        expect(
            options.integrations.any((i) => i is ReplayIntegration), isFalse);
        expect(options.integrations.any((i) => i is ReplayLogIntegration),
            isFalse);

        // Ordering: RunZonedGuarded before Widgets
        final runZonedIdx = options.integrations
            .indexWhere((i) => i is RunZonedGuardedIntegration);
        final widgetsIdx = options.integrations
            .indexWhere((i) => i is WidgetsFlutterBindingIntegration);
        expect(widgetsIdx, greaterThanOrEqualTo(0));
        if (runZonedIdx >= 0) {
          expect(runZonedIdx < widgetsIdx, isTrue);
        }
      });
    });

    group('Event processor ordering', () {
      testWidgets('adds FlutterEnricher before LoadContexts', (tester) async {
        if (kIsWeb) return;

        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        final isAndroid =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final isMacOS =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
        if (isAndroid || isIOS || isMacOS) {
          final processors = options.eventProcessors;
          final enricherIndex =
              processors.indexWhere((p) => p is FlutterEnricherEventProcessor);
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
      testWidgets('selects correct transport per platform', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        expect(options.transport, isA<ClientReportTransport>());
        final innerTransport =
            (options.transport as ClientReportTransport).innerTransport;
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
        final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
        if (kIsWeb) {
          expect(innerTransport, isA<JavascriptTransport>());
        } else if (isAndroid || isIOS || isMacOS) {
          expect(innerTransport, isA<FileSystemTransport>());
        } else {
          expect(innerTransport, isA<HttpTransport>());
        }
      });
    });

    group('Profiling', () {
      testWidgets('selects profiler factory per platform', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
            o.profilesSampleRate = 1.0;
          }, appRunner: () async {});
        });

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

    group('Thread info', () {
      testWidgets('adds ThreadInfoIntegration on non-web only', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        final hasThreadInfo = options.integrations
            .any((integration) => integration is ThreadInfoIntegration);
        if (kIsWeb) {
          expect(hasThreadInfo, isFalse);
        } else {
          expect(hasThreadInfo, isTrue);
        }
      });
    });

    group('Dart symbolication', () {
      testWidgets('disables Dart symbolication when native is present',
          (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.debug = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        if (SentryFlutter.native != null) {
          expect(options.enableDartSymbolication, isFalse);
        }
      });
    });

    group('Exception type identifiers', () {
      testWidgets('orders identifiers: Flutter before Dart', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
          }, appRunner: () async {});
        });

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
      testWidgets('adds ScreenshotIntegration when enabled', (tester) async {
        await restoreFlutterOnErrorAfter(() async {
          await SentryFlutter.init((o) {
            o.dsn = fakeDsn;
            o.attachScreenshot = true;
          }, appRunner: () async {});
        });

        final options = _currentOptions();
        final hasScreenshotIntegration = options.integrations
            .any((integration) => integration is ScreenshotIntegration);
        expect(hasScreenshotIntegration, isTrue);
      });
    });
  });
}
