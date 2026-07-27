// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
import 'package:sentry_flutter/src/app_start/standalone/streaming_app_start_trace.dart';

import '../../mocks.dart';

void main() {
  group('$StreamingAppStartTrace', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('encodes the standalone root after natural end', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;

      sut.recordFirstFrame(fixture.naturalEnd);
      root.end(endTimestamp: fixture.rootFinish);
      await pumpEventQueue(times: 10);

      expect(root.name, 'App Start');
      expect(root.attributes['sentry.op']?.value, 'app.start');
      expect(root.attributes['sentry.origin']?.value, 'auto.app.start');
      expect(root.attributes['app.vitals.start.value']?.value, 350.0);
      expect(root.attributes['app.vitals.start.cold.value']?.value, 350.0);
      expect(root.attributes['app.vitals.start.type']?.value, 'cold');
      expect(root.attributes['app.vitals.start.screen']?.value, 'root /');
      expect(root.attributes['sentry.segment.name']?.value, 'App Start');
    });

    test('creates direct standalone breakdown children', () {
      fixture.getSut();

      expect(fixture.children, hasLength(3));
      expect(
        fixture.children.map((span) => span.parentSpan),
        everyElement(same(fixture.root)),
      );
    });

    test('uses the first frame render operation for its span', () {
      fixture.getSut();
      final firstFrame = fixture.children.firstWhere(
        (span) => span.name == 'First frame render',
      );

      expect(
        firstFrame.attributes['sentry.op']?.value,
        'app.start.first_frame_render',
      );
    });

    test('keeps the root open after recording the first frame', () {
      final sut = fixture.getSut()!;
      final root = fixture.root!;
      final firstFrame = fixture.children.firstWhere(
        (span) => span.name == 'First frame render',
      );

      sut.recordFirstFrame(fixture.naturalEnd);

      expect(firstFrame.isEnded, isTrue);
      expect(root.isEnded, isFalse);
    });

    test('omits duration and retains metadata at deadline', () async {
      fixture.getSut();
      final root = fixture.root!;

      root.status = SentrySpanStatusV2.error;
      root.setAttribute(
        'sentry.status.message',
        SentryAttribute.string('deadline_exceeded'),
      );
      root.end(endTimestamp: fixture.processStart.add(Duration(seconds: 30)));
      await pumpEventQueue(times: 10);

      expect(root.attributes['app.vitals.start.value'], isNull);
      expect(root.attributes['app.vitals.start.type']?.value, 'cold');
      expect(root.attributes['app.vitals.start.screen']?.value, 'root /');
    });

    test('returns null when trace creation fails', () {
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (_) => throw StateError('sampling failed');

      expect(fixture.getSut(), isNull);
    });

    test(
        'returns null and ends the root when first frame render span is ignored',
        () {
      fixture.options.ignoreSpans = [
        IgnoreSpanRule.nameEquals('First frame render'),
      ];

      final trace = fixture.getSut();

      expect(trace, isNull);
      expect(fixture.root?.isEnded, isTrue);
      expect(fixture.processor.addedSpans, isEmpty);
    });

    test('returns null and ends created spans when phase creation throws',
        () async {
      final throwingFixture = ThrowingPhaseCreationFixture();

      final trace = throwingFixture.getSut();
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      expect(throwingFixture.hub.root?.isEnded, isTrue);
      expect(throwingFixture.hub.firstFrameBarrier?.isEnded, isTrue);
      expect(throwingFixture.hub.firstPhaseChild?.isEnded, isTrue);
    });

    // Aborting only ends the root, which relies on the root having been told
    // about its children. That notification is dispatched through the lifecycle
    // registry, so an already-registered listener sits ahead of the root in the
    // dispatch order — as FramesTrackingIntegration does in a real SDK.
    test('ends created spans when phase creation throws behind a listener',
        () async {
      final throwingFixture = ThrowingPhaseCreationFixture(
        leadingListener: (_) {},
      );

      final trace = throwingFixture.getSut();
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      expect(throwingFixture.hub.root?.isEnded, isTrue);
      expect(throwingFixture.hub.firstFrameBarrier?.isEnded, isTrue);
      expect(throwingFixture.hub.firstPhaseChild?.isEnded, isTrue);
    });

    test('deregisters its process-span callback after enriching', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;
      final registry = fixture.options.lifecycleRegistry;

      expect(registry.lifecycleCallbacks[OnProcessSpan], hasLength(1));

      sut.recordFirstFrame(fixture.naturalEnd);
      root.end(endTimestamp: fixture.rootFinish);
      await pumpEventQueue(times: 10);

      expect(registry.lifecycleCallbacks[OnProcessSpan], isEmpty);
    });

    test('close flushes the open root', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;

      await sut.close();
      await pumpEventQueue(times: 10);

      expect(root.isEnded, isTrue);
      expect(root.attributes['app.vitals.start.type']?.value, 'cold');
      expect(root.attributes['app.vitals.start.screen']?.value, 'root /');
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final naturalEnd = processStart.add(Duration(milliseconds: 350));
  late final rootFinish = processStart.add(Duration(milliseconds: 500));
  IdleRecordingSentrySpanV2? root;
  final children = <SentrySpanV2>[];
  final processor = MockTelemetryProcessor();

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
    ..telemetryProcessor = processor
    ..clock = () => processStart.add(Duration(milliseconds: 300));
  late final hub = Hub(options);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final timing = AppStartTiming(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: pluginRegistration,
    sentrySetupTimestamp: sentrySetup,
    phases: [
      AppStartPhase(
        kind: AppStartPhaseKind.pluginRegistration,
        description: 'App start to plugin registration',
        startTimestamp: processStart,
        endTimestamp: pluginRegistration,
      ),
      AppStartPhase(
        kind: AppStartPhaseKind.sentrySetup,
        description: 'Before Sentry Init Setup',
        startTimestamp: pluginRegistration,
        endTimestamp: sentrySetup,
      ),
    ],
  );

  Fixture() {
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      final span = event.span;
      if (span is IdleRecordingSentrySpanV2) {
        root ??= span;
      } else if (span.parentSpan != null) {
        children.add(span);
      }
    });
  }

  StreamingAppStartTrace? getSut() {
    return StreamingAppStartTrace.tryCreate(
      hub: hub,
      timing: timing,
      startScreenNameProvider: () => 'root /',
    );
  }
}

class ThrowingPhaseCreationFixture {
  ThrowingPhaseCreationFixture({this.leadingListener});

  /// Registered before the root exists, mirroring integrations that hook
  /// `OnSpanStartV2` during SDK init.
  final SdkLifecycleCallback<OnSpanStartV2>? leadingListener;

  final processStart = DateTime.utc(2024, 1, 1, 12);
  final processor = MockTelemetryProcessor();

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
    ..telemetryProcessor = processor
    ..clock = () => processStart.add(Duration(milliseconds: 300));
  late final baseHub = Hub(options);
  late final hub = _ThrowingOnPhaseStartHub(baseHub);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final timing = AppStartTiming(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: pluginRegistration,
    sentrySetupTimestamp: sentrySetup,
    phases: [
      AppStartPhase(
        kind: AppStartPhaseKind.pluginRegistration,
        description: 'App start to plugin registration',
        startTimestamp: processStart,
        endTimestamp: pluginRegistration,
      ),
      AppStartPhase(
        kind: AppStartPhaseKind.sentrySetup,
        description: 'Before Sentry Init Setup',
        startTimestamp: pluginRegistration,
        endTimestamp: sentrySetup,
      ),
    ],
  );

  StreamingAppStartTrace? getSut() {
    final listener = leadingListener;
    if (listener != null) {
      options.lifecycleRegistry.registerCallback<OnSpanStartV2>(listener);
    }
    return StreamingAppStartTrace.tryCreate(
      hub: hub,
      timing: timing,
      startScreenNameProvider: () => 'root /',
    );
  }
}

class _ThrowingOnPhaseStartHub extends NoOpHub {
  _ThrowingOnPhaseStartHub(this._delegate);

  final Hub _delegate;
  IdleRecordingSentrySpanV2? root;
  RecordingSentrySpanV2? firstFrameBarrier;
  RecordingSentrySpanV2? firstPhaseChild;

  @override
  SentryOptions get options => _delegate.options;

  @override
  SentrySpanV2 startIdleSpan(
    String name, {
    Duration idleTimeout = const Duration(seconds: 3),
    Duration finalTimeout = const Duration(seconds: 30),
    bool trimIdleSpanEndTimestamp = true,
    bool bindToHub = true,
    Map<String, SentryAttribute>? attributes,
    DateTime? startTimestamp,
  }) {
    final span = _delegate.startIdleSpan(
      name,
      idleTimeout: idleTimeout,
      finalTimeout: finalTimeout,
      trimIdleSpanEndTimestamp: trimIdleSpanEndTimestamp,
      bindToHub: bindToHub,
      attributes: attributes,
      startTimestamp: startTimestamp,
    );
    if (span is IdleRecordingSentrySpanV2) {
      root = span;
    }
    return span;
  }

  @override
  SentrySpanV2 startInactiveSpan(
    String name, {
    Map<String, SentryAttribute>? attributes,
    SentrySpanV2? parentSpan = const UnsetSentrySpanV2(),
    DateTime? startTimestamp,
  }) {
    if (name == 'Before Sentry Init Setup') {
      throw StateError('failed to start $name');
    }

    final span = _delegate.startInactiveSpan(
      name,
      attributes: attributes,
      parentSpan: parentSpan,
      startTimestamp: startTimestamp,
    );
    if (span is RecordingSentrySpanV2) {
      if (name == 'First frame render') {
        firstFrameBarrier = span;
      } else if (name == 'App start to plugin registration') {
        firstPhaseChild = span;
      }
    }
    return span;
  }
}
