// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/standalone/standalone_app_start_lifecycle.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

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
  List<SentrySpan> get appStartRoots =>
      rootSpans.where((span) => span.context.operation == 'app.start').toList();
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
