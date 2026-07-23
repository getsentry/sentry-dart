// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone/app_start_trace.dart';
import 'package:sentry_flutter/src/app_start/standalone/standalone_app_start_lifecycle.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

import '../../app_start_trace_test_support.dart';
import '../../fake_frame_callback_handler.dart';
import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  group('$StandaloneAppStartLifecycle', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() async {
      await fixture.getSut().close();
      fixture.setCurrentRouteName(null);
    });

    test(
        'allows app-start traces to expose both extension span types and explicit finish timestamps',
        () async {
      final fake = TestAppStartTrace();
      final AppStartTrace trace = fake;
      final extensionStart = DateTime.utc(2026, 7, 22, 16);
      final extensionEnd = DateTime.utc(2026, 7, 22, 16, 0, 1);

      expect(trace.tryExtend(extensionStart), isTrue);
      expect(trace.extendedSpan, isA<NoOpSentrySpan>());
      expect(trace.extendedSpanV2, isA<SentrySpanV2>());

      await trace.finishExtended(extensionEnd);

      expect(fake.extensionStart, extensionStart);
      expect(fake.extensionEnd, extensionEnd);
    });

    test('installs standalone trace before the first frame', () async {
      await fixture.startLifecycle();
      await pumpEventQueue();

      expect(fixture.appStartRoots, hasLength(1));
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test('retains native phases completed after SDK setup starts', () async {
      when(fixture.native.fetchNativeAppStart()).thenAnswer(
        (_) async => NativeAppStart(
          appStartTime: fixture.processStart.millisecondsSinceEpoch,
          pluginRegistrationTime: 100,
          isColdStart: true,
          nativeSpanTimes: {
            'Activity.onCreate': {
              'startTimestampMsSinceEpoch': 150,
              'stopTimestampMsSinceEpoch': 250,
            },
          },
        ),
      );

      await fixture.startLifecycle();

      expect(
        fixture.appStartRoots.single.tracer.children
            .map((span) => span.context.description),
        contains('Activity.onCreate'),
      );
    });

    test('samples sibling roots independently with one trace ID', () async {
      var samplerCalls = 0;
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (_) {
          samplerCalls++;
          return 1.0;
        };

      await fixture.startLifecycle();
      await pumpEventQueue();

      expect(samplerCalls, 2);
      expect(fixture.rootSpans, hasLength(2));
      expect(
        fixture.rootSpans.map((span) => span.context.traceId).toSet(),
        hasLength(1),
      );
    });

    test(
        'produces equivalent static and streaming outputs for nested extension completion',
        () async {
      final staticFixture = Fixture();
      final streamingFixture = Fixture()..useStreamingLifecycle();
      addTearDown(() async {
        await staticFixture.getSut().close();
        await streamingFixture.getSut().close();
      });

      final staticSnapshot = await staticFixture.runExtendedScenario();
      final streamingSnapshot = await streamingFixture.runExtendedScenario();

      expect(staticSnapshot.rootCount, 1);
      expect(streamingSnapshot.rootCount, 1);
      expect(staticSnapshot.extensionChildCount, 1);
      expect(streamingSnapshot.extensionChildCount, 1);
      expect(staticSnapshot.extensionStart, streamingSnapshot.extensionStart);
      expect(staticSnapshot.extensionEnd, streamingSnapshot.extensionEnd);
      expect(staticSnapshot.childEnd, streamingSnapshot.childEnd);
      expect(
        staticSnapshot.grandchildEnd,
        streamingSnapshot.grandchildEnd,
      );
      expect(staticSnapshot.extensionSuccessful, isTrue);
      expect(streamingSnapshot.extensionSuccessful, isTrue);
      expect(staticSnapshot.childOpenAfterExtension, isTrue);
      expect(staticSnapshot.grandchildOpenAfterExtension, isTrue);
      expect(streamingSnapshot.childOpenAfterExtension, isTrue);
      expect(streamingSnapshot.grandchildOpenAfterExtension, isTrue);
      expect(staticSnapshot.childSuccessful, isTrue);
      expect(staticSnapshot.grandchildSuccessful, isTrue);
      expect(streamingSnapshot.childSuccessful, isTrue);
      expect(streamingSnapshot.grandchildSuccessful, isTrue);
      expect(staticSnapshot.measurementMilliseconds, 600.0);
      expect(
        streamingSnapshot.measurementMilliseconds,
        staticSnapshot.measurementMilliseconds,
      );
      expect(streamingSnapshot.childStatusMessage, isNull);
      expect(streamingSnapshot.grandchildStatusMessage, isNull);
    });

    test('concurrent start calls initialize the lifecycle once', () async {
      final nativeAppStartCompleter = Completer<NativeAppStart?>();
      when(
        fixture.native.fetchNativeAppStart(),
      ).thenAnswer((_) => nativeAppStartCompleter.future);

      final firstStart = fixture.startLifecycle();
      final secondStart = fixture.startLifecycle();
      nativeAppStartCompleter.complete(fixture.nativeAppStart());

      await Future.wait([firstStart, secondStart]);
      await pumpEventQueue();

      final uiLoadRoots = fixture.rootSpans.where(
        (span) => span.context.operation == SentrySpanOperations.uiLoad,
      );
      verify(fixture.native.fetchNativeAppStart()).called(1);
      expect(fixture.appStartRoots, hasLength(1));
      expect(uiLoadRoots, hasLength(1));
      expect(fixture.frameHandler.registeredTimingsCallbacks, hasLength(1));
    });

    test('when app.start is unsampled still prepares sampled ui.load',
        () async {
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (samplingContext) {
          return samplingContext.transactionContext.operation ==
                  SentrySpanOperations.uiLoad
              ? 1.0
              : 0.0;
        };

      await fixture.startLifecycle();
      await pumpEventQueue();

      final uiLoadRoots = fixture.rootSpans
          .where(
              (span) => span.context.operation == SentrySpanOperations.uiLoad)
          .toList();

      expect(uiLoadRoots, hasLength(1));
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test(
        'when app.start is unsampled in stream lifecycle still prepares ui.load',
        () async {
      fixture.useStreamingLifecycle();
      fixture.options
        ..enableTimeToFullDisplayTracing = true
        ..tracesSampleRate = null
        ..tracesSampler = (samplingContext) {
          return samplingContext
                      .spanContext
                      .attributes[SemanticAttributesConstants.sentryOp]
                      ?.value ==
                  SentrySpanOperations.uiLoad
              ? 1.0
              : 0.0;
        };

      await fixture.startLifecycle();

      final activeSpan = fixture.hub.getActiveSpan();

      expect(activeSpan, isNotNull);
      expect(activeSpan!.name, 'root /');
      expect(fixture.options.timeToDisplayTrackerV2.ttfdSpanId, isNotNull);
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test('keeps the first-frame callback after empty timings', () async {
      await fixture.startLifecycle();
      final callback = fixture.frameHandler.timingsCallback!;

      callback([]);
      await pumpEventQueue();

      expect(fixture.frameHandler.timingsCallback, same(callback));

      callback([fixture.frameTiming]);
      await pumpEventQueue(times: 10);

      expect(fixture.frameHandler.timingsCallback, isNull);
    });

    test('when native timing is invalid prepares ui.load and callback',
        () async {
      when(fixture.native.fetchNativeAppStart()).thenAnswer(
        (_) async => fixture.nativeAppStart(appStartMilliseconds: 1000),
      );

      await fixture.startLifecycle();

      final uiLoadRoot = fixture.rootSpans.single;

      expect(uiLoadRoot.context.operation, SentrySpanOperations.uiLoad);
      expect(uiLoadRoot.startTimestamp, fixture.setup);
      expect(fixture.appStartRoots, isEmpty);
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test(
        'when native timing is unavailable in stream lifecycle prepares ui.load and ttfd',
        () async {
      fixture.useStreamingLifecycle();
      fixture.options.enableTimeToFullDisplayTracing = true;
      when(fixture.native.fetchNativeAppStart()).thenAnswer((_) async => null);

      await fixture.startLifecycle();

      final activeSpan = fixture.hub.getActiveSpan();

      expect(activeSpan, isNotNull);
      expect(activeSpan!.name, 'root /');
      expect(activeSpan.startTimestamp, fixture.setup);
      expect(fixture.options.timeToDisplayTrackerV2.ttfdSpanId, isNotNull);
      expect(fixture.frameHandler.timingsCallback, isNotNull);
    });

    test('close without start does not clear legacy static display tracking',
        () async {
      final transactionId = fixture.seedLegacyStaticDisplayTracking();

      await fixture.getSut().close();

      expect(fixture.options.timeToDisplayTracker.transactionId, transactionId);
    });

    test('close without start does not clear legacy stream display tracking',
        () async {
      fixture.useStreamingLifecycle();
      fixture.options.enableTimeToFullDisplayTracing = true;
      final ttfdSpanId = fixture.seedLegacyStreamDisplayTracking();

      expect(ttfdSpanId, isNotNull);

      await fixture.getSut().close();

      expect(fixture.options.timeToDisplayTrackerV2.ttfdSpanId, ttfdSpanId);
    });

    test('close flushes the standalone trace', () async {
      await fixture.startLifecycle();
      await pumpEventQueue();
      final root = fixture.appStartRoots.single;

      await fixture.getSut().close();
      await pumpEventQueue(times: 10);

      expect(root.tracer.finished, isTrue);
    });

    test('publishes the active standalone trace after start', () async {
      await fixture.startLifecycle();

      expect(fixture.options.standaloneAppStartTrace, isNotNull);
    });

    test('close clears the published standalone trace', () async {
      await fixture.startLifecycle();
      final publishedTrace = fixture.options.standaloneAppStartTrace;

      expect(publishedTrace, isNotNull);

      await fixture.getSut().close();

      expect(fixture.options.standaloneAppStartTrace, isNull);
    });

    test('close preserves a replacement standalone trace', () async {
      await fixture.startLifecycle();
      final publishedTrace = fixture.options.standaloneAppStartTrace;
      final replacementTrace = TestAppStartTrace();

      expect(publishedTrace, isNotNull);

      fixture.options.standaloneAppStartTrace = replacementTrace;

      await fixture.getSut().close();

      expect(
        fixture.options.standaloneAppStartTrace,
        same(replacementTrace),
      );
    });

    test('close removes the first-frame callback', () async {
      await fixture.startLifecycle();

      expect(fixture.frameHandler.timingsCallback, isNotNull);

      await fixture.getSut().close();

      expect(fixture.frameHandler.timingsCallback, isNull);
    });

    test('finishes app start without waiting for full display', () async {
      fixture.options.enableTimeToFullDisplayTracing = true;
      await fixture.startLifecycle();
      final root = fixture.appStartRoots.single.tracer;
      final firstFrameSpan = root.children.singleWhere(
        (span) =>
            span.context.operation ==
            SentrySpanOperations.appStartFirstFrameRender,
      );

      fixture.frameHandler.timingsCallback!([fixture.frameTiming]);
      await pumpEventQueue(times: 10);

      try {
        expect(firstFrameSpan.finished, isTrue);
      } finally {
        await fixture.options.timeToDisplayTracker.reportFullyDisplayed(
          spanId: fixture.options.timeToDisplayTracker.transactionId,
        );
        await pumpEventQueue(times: 10);
      }
    });

    test('close while native fetch is pending prevents later work', () async {
      final nativeAppStartCompleter = Completer<NativeAppStart?>();
      when(
        fixture.native.fetchNativeAppStart(),
      ).thenAnswer((_) => nativeAppStartCompleter.future);

      final startFuture = fixture.startLifecycle();
      await fixture.getSut().close();

      nativeAppStartCompleter.complete(fixture.nativeAppStart());
      await startFuture;
      await pumpEventQueue(times: 10);

      expect(fixture.rootSpans, isEmpty);
      expect(fixture.frameHandler.timingsCallback, isNull);
    });

    test('captures the app-start screen at the first valid frame', () async {
      fixture.setCurrentRouteName('launch');
      await fixture.startLifecycle();
      final root = fixture.appStartRoots.single.tracer;

      fixture.frameHandler.timingsCallback!([fixture.frameTiming]);
      await pumpEventQueue(times: 10);
      fixture.setCurrentRouteName('next');
      await root.finish(endTimestamp: fixture.snapshot);

      expect(root.data['app.vitals.start.screen'], 'launch');
    });

    test('maps the navigator root route to root /', () async {
      fixture.setCurrentRouteName('/');
      await fixture.startLifecycle();
      final root = fixture.appStartRoots.single.tracer;

      fixture.frameHandler.timingsCallback!([fixture.frameTiming]);
      await pumpEventQueue(times: 10);
      await root.finish(endTimestamp: fixture.snapshot);

      expect(root.data['app.vitals.start.screen'], 'root /');
    });
  });
}

class Fixture {
  final frameHandler = _RecordingFrameCallbackHandler();
  final native = MockSentryNativeBinding();
  final transport = _FakeTransport();
  final rootSpans = <SentrySpan>[];
  final streamRootSpans = <IdleRecordingSentrySpanV2>[];
  final streamChildSpans = <RecordingSentrySpanV2>[];
  List<SentrySpan> get appStartRoots =>
      rootSpans.where((span) => span.context.operation == 'app.start').toList();
  List<IdleRecordingSentrySpanV2> get streamAppStartRoots => streamRootSpans
      .where(
        (span) =>
            span.attributes[SemanticAttributesConstants.sentryOp]?.value ==
            SentrySpanOperations.appStart,
      )
      .toList();
  final processStart = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final setup = DateTime.fromMillisecondsSinceEpoch(200, isUtc: true);
  final snapshot = DateTime.fromMillisecondsSinceEpoch(300, isUtc: true);
  final frameTiming = FrameTiming(
    vsyncStart: 400000,
    buildStart: 400000,
    buildFinish: 400000,
    rasterStart: 400000,
    rasterFinish: 400000,
    rasterFinishWallTime: 400000,
  );

  late final options = defaultTestOptions(platform: MockPlatform.android())
    ..transport = transport
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.static
    ..enableStandaloneAppStartTracing = true
    ..clock = () => snapshot;
  late final hub = Hub(options);
  late final navigatorObserver = SentryNavigatorObserver(
    hub: hub,
    enableAutoTransactions: false,
  );
  late final _sut = StandaloneAppStartLifecycle(
    hub: hub,
    frameCallbackHandler: frameHandler,
    native: native,
  );

  Fixture() {
    SentryFlutter.sentrySetupStartTime = setup;
    options.lifecycleRegistry.registerCallback<OnSpanStart>((event) {
      if (event.span is SentrySpan && (event.span as SentrySpan).isRootSpan) {
        rootSpans.add(event.span as SentrySpan);
      }
    });
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      final span = event.span;
      if (span is IdleRecordingSentrySpanV2) {
        streamRootSpans.add(span);
      } else if (span is RecordingSentrySpanV2 && span.parentSpan != null) {
        streamChildSpans.add(span);
      }
    });
    options.timeToDisplayTracker = TimeToDisplayTracker(
      hub: hub,
      options: options,
    );
    options.timeToDisplayTrackerV2 = TimeToDisplayTrackerV2(
      hub: hub,
      frameCallbackHandler: frameHandler,
    );
    when(
      native.fetchNativeAppStart(),
    ).thenAnswer((_) async => nativeAppStart());
  }

  StandaloneAppStartLifecycle getSut() => _sut;

  NativeAppStart nativeAppStart({int appStartMilliseconds = 0}) =>
      NativeAppStart(
        appStartTime: appStartMilliseconds,
        pluginRegistrationTime: 100,
        isColdStart: true,
        nativeSpanTimes: {},
      );

  Future<void> startLifecycle() => getSut().start();

  Future<_ExtendedScenarioSnapshot> runExtendedScenario() async {
    final extensionStart = processStart.add(const Duration(milliseconds: 250));
    final childStart = extensionStart.add(const Duration(milliseconds: 25));
    final grandchildStart =
        extensionStart.add(const Duration(milliseconds: 50));
    final extensionEnd = processStart.add(const Duration(milliseconds: 600));
    final grandchildEnd = processStart.add(const Duration(milliseconds: 700));
    final childEnd = processStart.add(const Duration(milliseconds: 800));
    final rootEnd = processStart.add(const Duration(milliseconds: 900));

    await startLifecycle();
    await pumpEventQueue(times: 10);

    final trace = options.standaloneAppStartTrace!;
    expect(trace.tryExtend(extensionStart), isTrue);

    switch (options.traceLifecycle) {
      case SentryTraceLifecycle.static:
        final extension = trace.extendedSpan as SentrySpan;
        final child = extension.startChild(
          'extended child',
          startTimestamp: childStart,
        ) as SentrySpan;
        final grandchild = child.startChild(
          'extended grandchild',
          startTimestamp: grandchildStart,
        ) as SentrySpan;

        frameHandler.timingsCallback!([frameTiming]);
        await pumpEventQueue(times: 10);
        await trace.finishExtended(extensionEnd);
        final childOpenAfterExtension = !child.finished;
        final grandchildOpenAfterExtension = !grandchild.finished;
        await grandchild.finish(
          status: SpanStatus.ok(),
          endTimestamp: grandchildEnd,
        );
        await child.finish(status: SpanStatus.ok(), endTimestamp: childEnd);
        await pumpEventQueue(times: 10);
        await appStartRoots.single.tracer.finish(endTimestamp: rootEnd);
        await pumpEventQueue(times: 10);

        return _ExtendedScenarioSnapshot(
          rootCount: appStartRoots.length,
          extensionChildCount: appStartRoots.single.tracer.children
              .where(
                (span) =>
                    span.context.operation ==
                    SentrySpanOperations.appStartExtended,
              )
              .length,
          extensionStart: extension.startTimestamp,
          extensionEnd: extension.endTimestamp!,
          childEnd: child.endTimestamp!,
          grandchildEnd: grandchild.endTimestamp!,
          extensionSuccessful: extension.status == SpanStatus.ok(),
          childOpenAfterExtension: childOpenAfterExtension,
          grandchildOpenAfterExtension: grandchildOpenAfterExtension,
          childSuccessful: child.status == SpanStatus.ok(),
          grandchildSuccessful: grandchild.status == SpanStatus.ok(),
          measurementMilliseconds: appStartRoots
              .single.tracer.measurements['app_start_cold']!.value
              .toDouble(),
        );
      case SentryTraceLifecycle.stream:
        final extension = trace.extendedSpanV2 as RecordingSentrySpanV2;
        final child = hub.startInactiveSpan(
          'extended child',
          parentSpan: extension,
          startTimestamp: childStart,
        ) as RecordingSentrySpanV2;
        final grandchild = hub.startInactiveSpan(
          'extended grandchild',
          parentSpan: child,
          startTimestamp: grandchildStart,
        ) as RecordingSentrySpanV2;

        frameHandler.timingsCallback!([frameTiming]);
        await pumpEventQueue(times: 10);
        await trace.finishExtended(extensionEnd);
        final childOpenAfterExtension = !child.isEnded;
        final grandchildOpenAfterExtension = !grandchild.isEnded;
        grandchild.end(endTimestamp: grandchildEnd);
        child.end(endTimestamp: childEnd);
        await pumpEventQueue(times: 10);
        streamAppStartRoots.single.end(endTimestamp: rootEnd);
        await pumpEventQueue(times: 10);

        return _ExtendedScenarioSnapshot(
          rootCount: streamAppStartRoots.length,
          extensionChildCount: streamChildSpans
              .where(
                (span) =>
                    identical(span.parentSpan, streamAppStartRoots.single) &&
                    span.attributes[SemanticAttributesConstants.sentryOp]
                            ?.value ==
                        SentrySpanOperations.appStartExtended,
              )
              .length,
          extensionStart: extension.startTimestamp,
          extensionEnd: extension.endTimestamp!,
          childEnd: child.endTimestamp!,
          grandchildEnd: grandchild.endTimestamp!,
          extensionSuccessful: extension.status == SentrySpanStatusV2.ok,
          childOpenAfterExtension: childOpenAfterExtension,
          grandchildOpenAfterExtension: grandchildOpenAfterExtension,
          childSuccessful: child.status == SentrySpanStatusV2.ok,
          grandchildSuccessful: grandchild.status == SentrySpanStatusV2.ok,
          measurementMilliseconds: streamAppStartRoots
              .single
              .attributes[SemanticAttributesConstants.appVitalsStartValue]!
              .value as double,
          childStatusMessage: child
              .attributes[SemanticAttributesConstants.sentryStatusMessage]
              ?.value as String?,
          grandchildStatusMessage: grandchild
              .attributes[SemanticAttributesConstants.sentryStatusMessage]
              ?.value as String?,
        );
    }
  }

  SpanId seedLegacyStaticDisplayTracking() {
    final transactionId = SentryTransactionContext(
      'root /',
      SentrySpanOperations.uiLoad,
      origin: SentryTraceOrigins.autoUiTimeToDisplay,
    ).spanId;
    options.timeToDisplayTracker.transactionId = transactionId;
    return transactionId;
  }

  SpanId? seedLegacyStreamDisplayTracking() {
    options.timeToDisplayTrackerV2.prepareAppStart(startTimestamp: setup);
    return options.timeToDisplayTrackerV2.ttfdSpanId;
  }

  void useStreamingLifecycle() {
    options.traceLifecycle = SentryTraceLifecycle.stream;
  }

  void setCurrentRouteName(String? name) {
    navigatorObserver.didPush(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        settings: RouteSettings(name: name),
      ),
      null,
    );
  }
}

final class _ExtendedScenarioSnapshot {
  final int rootCount;
  final int extensionChildCount;
  final DateTime extensionStart;
  final DateTime extensionEnd;
  final DateTime childEnd;
  final DateTime grandchildEnd;
  final bool extensionSuccessful;
  final bool childOpenAfterExtension;
  final bool grandchildOpenAfterExtension;
  final bool childSuccessful;
  final bool grandchildSuccessful;
  final double measurementMilliseconds;
  final String? childStatusMessage;
  final String? grandchildStatusMessage;

  const _ExtendedScenarioSnapshot({
    required this.rootCount,
    required this.extensionChildCount,
    required this.extensionStart,
    required this.extensionEnd,
    required this.childEnd,
    required this.grandchildEnd,
    required this.extensionSuccessful,
    required this.childOpenAfterExtension,
    required this.grandchildOpenAfterExtension,
    required this.childSuccessful,
    required this.grandchildSuccessful,
    required this.measurementMilliseconds,
    this.childStatusMessage,
    this.grandchildStatusMessage,
  });
}

class _FakeTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => SentryId.empty();
}

class _RecordingFrameCallbackHandler extends FakeFrameCallbackHandler {
  final registeredTimingsCallbacks = <TimingsCallback>{};

  @override
  void addTimingsCallback(TimingsCallback callback) {
    registeredTimingsCallbacks.add(callback);
    super.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    registeredTimingsCallbacks.remove(callback);
    super.removeTimingsCallback(callback);
  }
}
