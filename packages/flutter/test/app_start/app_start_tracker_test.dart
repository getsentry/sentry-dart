// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:sentry_flutter/src/app_start/app_start_info.dart';
import 'package:sentry_flutter/src/app_start/app_start_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$AppStartTracker', () {
    group('in stream lifecycle', () {
      group('with standalone disabled', () {
        test('attaches app start span to ui.load root', () async {
          final sut = fixture.getSut();

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final appStartSpan = fixture.findSpanByName('Cold Start');
          expect(appStartSpan, isNotNull);
          expect(appStartSpan!.parentSpan?.name, 'root /');
        });

        test('does not create App Start root', () async {
          final sut = fixture.getSut();

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          expect(fixture.findSpanByName('App Start'), isNull);
        });
      });

      group('with standalone enabled', () {
        test('creates detached App Start root with app.start op', () async {
          final sut = fixture.getSut(standalone: true);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final root = fixture.findSpanByName('App Start');
          expect(root, isNotNull);
          expect(root!.parentSpan, isNull);
          expect(
            root.attributes[SemanticAttributesConstants.sentryOp]?.value,
            'app.start',
          );
          expect(
            root.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
            'auto.app.start',
          );
          expect(root.startTimestamp, fixture.appStartDateTime.toUtc());
          expect(root.isEnded, isTrue);
          expect(root.endTimestamp, fixture.appStartEnd.toUtc());
        });

        test('attaches breakdown spans directly under App Start root',
            () async {
          final sut = fixture.getSut(standalone: true);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          expect(fixture.findSpanByName('Cold Start'), isNull);
          final root = fixture.findSpanByName('App Start');
          expect(
            fixture.findSpanByName('First frame render')?.parentSpan,
            same(root),
          );
          expect(
            fixture.findSpanByName('native span 1')?.parentSpan,
            same(root),
          );
          expect(
            fixture
                .findSpanByName('App start to plugin registration')
                ?.parentSpan,
            same(root),
          );
        });

        test('assigns a dedicated operation per breakdown span', () async {
          final sut = fixture.getSut(standalone: true);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          expect(
            fixture.spanOperation('App start to plugin registration'),
            'app.start.plugin_registration',
          );
          expect(
            fixture.spanOperation('Before Sentry Init Setup'),
            'app.start.sentry_setup',
          );
          expect(
            fixture.spanOperation('First frame render'),
            'app.start.first_frame_render',
          );
          expect(
            fixture.spanOperation('native span 1'),
            'app.start.native',
          );
        });

        test('writes value and type attributes on App Start root', () async {
          final sut = fixture.getSut(standalone: true);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final root = fixture.findSpanByName('App Start')!;
          expect(root.attributes['app.vitals.start.value']?.value, 50.0);
          expect(root.attributes['app.vitals.start.cold.value']?.value, 50.0);
          expect(root.attributes['app.vitals.start.type']?.value, 'cold');
        });

        test('keeps ui.load root backdated without app start payload',
            () async {
          final sut = fixture.getSut(standalone: true);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final uiLoadRoot = fixture.findSpanByName('root /');
          expect(uiLoadRoot, isNotNull);
          expect(uiLoadRoot!.startTimestamp, fixture.appStartDateTime.toUtc());
          final uiLoadChildren = fixture.capturedSpans
              .where((s) => s.parentSpan == uiLoadRoot)
              .map((s) => s.name);
          expect(uiLoadChildren, isNot(contains('Cold Start')));
          expect(
            uiLoadRoot.attributes['app.vitals.start.value'],
            isNull,
          );
        });

        test('shares trace with ui.load root', () async {
          final sut = fixture.getSut(standalone: true);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final root = fixture.findSpanByName('App Start')!;
          final uiLoadRoot = fixture.findSpanByName('root /')!;
          expect(root.traceId, uiLoadRoot.traceId);
        });
      });

      test('tracks only the first call', () async {
        final sut = fixture.getSut(standalone: true);

        await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);
        await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

        final appStartRoots =
            fixture.capturedSpans.where((s) => s.name == 'App Start');
        expect(appStartRoots, hasLength(1));
      });
    });

    group('in static lifecycle', () {
      group('with standalone enabled', () {
        test('captures standalone App Start transaction', () async {
          final sut = fixture.getSut(
            standalone: true,
            lifecycle: SentryTraceLifecycle.static,
          );
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final transaction = fixture.capturedTransactionByName('App Start');
          expect(transaction, isNotNull);
          expect(transaction!.contexts.trace?.operation, 'app.start');
          expect(transaction.contexts.trace?.origin, 'auto.app.start');
          expect(transaction.startTimestamp, fixture.appStartDateTime.toUtc());
          expect(transaction.timestamp, fixture.appStartEnd.toUtc());
        });

        test('writes measurement and data in the finish path', () async {
          final sut = fixture.getSut(
            standalone: true,
            lifecycle: SentryTraceLifecycle.static,
          );
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final transaction = fixture.capturedTransactionByName('App Start')!;
          final measurement = transaction.measurements['app_start_cold']!;
          expect(measurement.value, 50);
          expect(transaction.tracer.data['app_start_type'], 'cold');
          expect(transaction.tracer.data['app.vitals.start.value'], 50.0);
          expect(transaction.tracer.data['app.vitals.start.type'], 'cold');
        });

        test('attaches breakdown spans to App Start transaction', () async {
          final sut = fixture.getSut(
            standalone: true,
            lifecycle: SentryTraceLifecycle.static,
          );
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final transaction = fixture.capturedTransactionByName('App Start')!;
          final spanDescriptions =
              transaction.spans.map((s) => s.context.description);
          expect(spanDescriptions, isNot(contains('Cold Start')));
          expect(spanDescriptions, contains('First frame render'));
          expect(spanDescriptions, contains('native span 1'));
          final rootSpanId = transaction.contexts.trace?.spanId;
          for (final span in transaction.spans) {
            expect(span.context.parentSpanId, rootSpanId);
          }
        });

        test('assigns a dedicated operation per breakdown span', () async {
          final sut = fixture.getSut(
            standalone: true,
            lifecycle: SentryTraceLifecycle.static,
          );
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final transaction = fixture.capturedTransactionByName('App Start')!;
          String? operationFor(String description) => transaction.spans
              .firstWhereOrNull((s) => s.context.description == description)
              ?.context
              .operation;
          expect(
            operationFor('App start to plugin registration'),
            'app.start.plugin_registration',
          );
          expect(
            operationFor('Before Sentry Init Setup'),
            'app.start.sentry_setup',
          );
          expect(
            operationFor('First frame render'),
            'app.start.first_frame_render',
          );
          expect(operationFor('native span 1'), 'app.start.native');
        });

        test('keeps ui.load transaction backdated without app start payload',
            () async {
          final sut = fixture.getSut(
            standalone: true,
            lifecycle: SentryTraceLifecycle.static,
          );
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final uiLoadTracer = fixture.scopeBoundTracer();
          expect(uiLoadTracer, isNotNull);
          expect(
            uiLoadTracer!.startTimestamp,
            fixture.appStartDateTime.toUtc(),
          );
          expect(uiLoadTracer.measurements['app_start_cold'], isNull);
          expect(
            uiLoadTracer.children
                .map((s) => s.context.description)
                .where((d) => d == 'Cold Start'),
            isEmpty,
          );
        });

        test('shares trace between App Start and ui.load', () async {
          final sut = fixture.getSut(
            standalone: true,
            lifecycle: SentryTraceLifecycle.static,
          );
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final transaction = fixture.capturedTransactionByName('App Start')!;
          final uiLoadTracer = fixture.scopeBoundTracer()!;
          expect(
            transaction.contexts.trace?.traceId,
            uiLoadTracer.context.traceId,
          );
        });
      });

      group('with standalone disabled', () {
        test('keeps app start payload on ui.load transaction', () async {
          final sut = fixture.getSut(lifecycle: SentryTraceLifecycle.static);
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          final uiLoadTracer = fixture.scopeBoundTracer();
          expect(uiLoadTracer, isNotNull);
          expect(uiLoadTracer!.measurements['app_start_cold']?.value, 50);
          expect(
            uiLoadTracer.children.map((s) => s.context.description),
            contains('Cold Start'),
          );
        });

        test('does not capture App Start transaction', () async {
          final sut = fixture.getSut(lifecycle: SentryTraceLifecycle.static);
          sut.prepare(fixture.hub, fixture.options);

          await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

          expect(fixture.capturedTransactionByName('App Start'), isNull);
        });
      });

      test('prepare sets display tracker transaction id and root context',
          () async {
        final sut = fixture.getSut(lifecycle: SentryTraceLifecycle.static);

        sut.prepare(fixture.hub, fixture.options);

        expect(fixture.options.timeToDisplayTracker.transactionId, isNotNull);

        await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

        final uiLoadTracer = fixture.scopeBoundTracer()!;
        expect(uiLoadTracer.name, 'root /');
        expect(uiLoadTracer.context.operation, 'ui.load');
        expect(
          uiLoadTracer.context.spanId,
          fixture.options.timeToDisplayTracker.transactionId,
        );
      });

      test('does not track without prepared context', () async {
        final sut = fixture.getSut(
          standalone: true,
          lifecycle: SentryTraceLifecycle.static,
        );

        await sut.track(fixture.hub, fixture.options, fixture.appStartInfo);

        expect(fixture.capturedTransactionByName('App Start'), isNull);
        expect(fixture.scopeBoundTracer(), isNull);
      });
    });
  });
}

class Fixture {
  final appStartDateTime = DateTime.fromMillisecondsSinceEpoch(0);
  final pluginRegistrationDateTime = DateTime.fromMillisecondsSinceEpoch(10);
  final sentrySetupStartDateTime = DateTime.fromMillisecondsSinceEpoch(15);
  final appStartEnd = DateTime.fromMillisecondsSinceEpoch(50);

  final frameCallbackHandler = FakeFrameCallbackHandler();

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
    ..enableTimeToFullDisplayTracing = true;

  late final hub = Hub(options);

  final capturedSpans = <RecordingSentrySpanV2>[];

  late final appStartInfo = AppStartInfo(
    AppStartType.cold,
    start: appStartDateTime,
    end: appStartEnd,
    pluginRegistration: pluginRegistrationDateTime,
    sentrySetupStart: sentrySetupStartDateTime,
    nativeSpanTimes: [
      TimeSpan(
        start: DateTime.fromMillisecondsSinceEpoch(1),
        end: DateTime.fromMillisecondsSinceEpoch(2),
        description: 'native span 1',
      ),
    ],
  );

  final client = MockSentryClient();
  final capturedTransactions = <SentryTransaction>[];

  Fixture() {
    SentryFlutter.sentrySetupStartTime = sentrySetupStartDateTime;

    options.timeToDisplayTrackerV2 = TimeToDisplayTrackerV2(
      hub: hub,
      frameCallbackHandler: frameCallbackHandler,
    );

    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span case final RecordingSentrySpanV2 span) {
        capturedSpans.add(span);
      }
    });

    when(client.captureTransaction(
      any,
      scope: anyNamed('scope'),
      traceContext: anyNamed('traceContext'),
      hint: anyNamed('hint'),
    )).thenAnswer((invocation) async {
      capturedTransactions
          .add(invocation.positionalArguments[0] as SentryTransaction);
      return SentryId.newId();
    });
  }

  AppStartTracker getSut({
    bool standalone = false,
    SentryTraceLifecycle lifecycle = SentryTraceLifecycle.stream,
  }) {
    options.enableStandaloneAppStartTracing = standalone;
    options.traceLifecycle = lifecycle;
    if (lifecycle == SentryTraceLifecycle.static) {
      // TTFD would keep the V1 display tracker waiting for a report.
      options.enableTimeToFullDisplayTracing = false;
      hub.bindClient(client);
    }
    return AppStartTracker();
  }

  RecordingSentrySpanV2? findSpanByName(String name) {
    return capturedSpans.firstWhereOrNull((s) => s.name == name);
  }

  Object? spanOperation(String name) {
    return findSpanByName(name)
        ?.attributes[SemanticAttributesConstants.sentryOp]
        ?.value;
  }

  SentryTransaction? capturedTransactionByName(String name) {
    return capturedTransactions.firstWhereOrNull((t) => t.transaction == name);
  }

  SentryTracer? scopeBoundTracer() {
    SentryTracer? tracer;
    hub.configureScope((scope) {
      tracer = scope.span as SentryTracer?;
    });
    return tracer;
  }
}
