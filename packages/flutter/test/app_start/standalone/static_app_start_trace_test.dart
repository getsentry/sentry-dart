// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_data.dart';
import 'package:sentry_flutter/src/app_start/standalone/static_app_start_trace.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

void main() {
  group('$StaticAppStartTrace', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('encodes the standalone root after natural end', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await pumpEventQueue(times: 10);
      await root.finish(endTimestamp: fixture.rootFinish);

      expect(root.name, 'App Start');
      expect(root.context.operation, 'app.start');
      expect(root.origin, 'auto.app.start');
      expect(root.measurements['app_start_cold']?.value, 350);
      expect(root.data['app_start_type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    test('creates direct standalone breakdown children', () {
      fixture.getSut();
      final root = fixture.root!.tracer;

      expect(root.children, hasLength(3));
      expect(
        root.children.map((span) => span.context.parentSpanId),
        everyElement(root.context.spanId),
      );
    });

    test('uses the first frame render operation for its barrier', () {
      fixture.getSut();
      final firstFrame = fixture.root!.tracer.children.firstWhere(
        (span) => span.context.description == 'First frame render',
      );

      expect(firstFrame.context.operation, 'app.start.first_frame_render');
    });

    test('sets app-start origin on its first-frame barrier', () {
      fixture.getSut();
      final firstFrame = fixture.root!.tracer.children.firstWhere(
        (span) => span.context.description == 'First frame render',
      );

      expect(firstFrame.origin, 'auto.app.start');
    });

    test('keeps the root open after recording the first frame', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      final firstFrame = root.children.firstWhere(
        (span) => span.context.description == 'First frame render',
      );

      sut.recordFirstFrame(fixture.naturalEnd);
      await pumpEventQueue(times: 10);

      expect(firstFrame.finished, isTrue);
      expect(root.finished, isFalse);
    });

    test('omits duration and retains metadata at deadline', () async {
      fixture.getSut();
      final root = fixture.root!.tracer;
      final deadline = fixture.processStart.add(Duration(seconds: 30));

      await root.children.first.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: deadline,
      );
      await root.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: deadline,
      );

      expect(root.measurements['app_start_cold'], isNull);
      expect(root.data['app_start_type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    test('returns null when root is unsampled', () {
      fixture.options.tracesSampleRate = 0;

      expect(fixture.getSut(), isNull);
    });

    test('returns null and finishes the unsampled root immediately', () async {
      fixture.options.tracesSampleRate = 0;

      final trace = fixture.getSut();
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      expect(fixture.root?.tracer.finished, isTrue);
    });

    test(
        'returns null and finishes the root when first frame barrier creation fails',
        () async {
      final trace = fixture.getSut(
        data: fixture.withFirstFrameBeforeProcessStart(),
      );
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      expect(fixture.root?.tracer.finished, isTrue);
    });

    test('returns null when trace creation fails', () {
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (_) => throw StateError('sampling failed');

      expect(fixture.getSut(), isNull);
    });

    test('close flushes the open root', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await sut.close();
      await pumpEventQueue(times: 10);

      expect(root.finished, isTrue);
      expect(root.data['app_start_type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    testWidgets('waits for idle timeout after natural end', (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await tester.pump(Duration(seconds: 2));
      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await tester.pump(Duration(seconds: 1));

      expect(root.finished, isFalse);

      await tester.pump(Duration(seconds: 2));
      await tester.pump();

      expect(root.finished, isTrue);
    });

    testWidgets('restarts idle timeout after a late first frame',
        (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await tester.pump(Duration(seconds: 4));
      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await tester.pump();

      expect(root.finished, isFalse);

      await tester.pump(Duration(seconds: 3));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.measurements['app_start_cold']?.value, 350);
    });

    test(
        'returns null and flushes provisional children when final timeout '
        'scheduling fails', () async {
      final mockFixture = MockCreationFixture();

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      );
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      verify(mockFixture.firstFrameBarrier.finish()).called(1);
      verify(
        mockFixture.pluginRegistrationChild.finish(
          endTimestamp: mockFixture.pluginRegistration,
        ),
      ).called(1);
      verify(mockFixture.pluginRegistrationChild.finish()).called(1);
      verify(
        mockFixture.sentrySetupChild.finish(
          endTimestamp: mockFixture.sentrySetup,
        ),
      ).called(1);
      verify(mockFixture.sentrySetupChild.finish()).called(1);
      verify(mockFixture.root.finish()).called(1);
    });

    test(
        'returns null and still finishes later spans when one provisional '
        'child flush throws', () async {
      final mockFixture = MockChildFlushFailureFixture();

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      );
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      verify(mockFixture.pluginRegistrationChild.finish()).called(1);
      verify(mockFixture.sentrySetupChild.finish()).called(1);
      verify(mockFixture.root.finish()).called(1);
    });

    test('returns null and flushes created spans when phase creation throws',
        () async {
      final mockFixture = MockPhaseCreationFailureFixture();

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      );
      await pumpEventQueue(times: 10);

      expect(trace, isNull);
      verify(mockFixture.firstFrameBarrier.finish()).called(1);
      verify(mockFixture.pluginRegistrationChild.finish()).called(1);
      verify(mockFixture.root.finish()).called(1);
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final naturalEnd = processStart.add(Duration(milliseconds: 350));
  late final rootFinish = processStart.add(Duration(milliseconds: 500));
  SentrySpan? root;

  final transport = _FakeTransport();

  late final options = defaultTestOptions()
    ..transport = transport
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.static
    ..clock = () => processStart.add(Duration(milliseconds: 300));
  late final hub = Hub(options);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final data = AppStartData(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: pluginRegistration,
    sentrySetupTimestamp: sentrySetup,
    phases: [
      AppStartPhase(
        operation: SentrySpanOperations.appStartPluginRegistration,
        description: 'App start to plugin registration',
        startTimestamp: processStart,
        endTimestamp: pluginRegistration,
      ),
      AppStartPhase(
        operation: SentrySpanOperations.appStartSentrySetup,
        description: 'Before Sentry Init Setup',
        startTimestamp: pluginRegistration,
        endTimestamp: sentrySetup,
      ),
    ],
  );

  AppStartData withFirstFrameBeforeProcessStart() {
    return AppStartData(
      type: data.type,
      processStartTimestamp: processStart,
      pluginRegistrationTimestamp: pluginRegistration,
      sentrySetupTimestamp: processStart.subtract(Duration(milliseconds: 1)),
      phases: data.phases,
    );
  }

  StaticAppStartTrace? getSut({AppStartData? data}) {
    options.lifecycleRegistry.registerCallback<OnSpanStart>((event) {
      final span = event.span;
      if (span is SentrySpan && span.isRootSpan) root ??= span;
    });
    return StaticAppStartTrace.tryCreate(
      hub: hub,
      data: data ?? this.data,
      startScreenNameProvider: () => 'root /',
    );
  }
}

class _FakeTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => SentryId.empty();
}

class _FinalTimeoutFailingTracer extends MockSentryTracer {
  @override
  bool tryScheduleFinalTimeout(DateTime deadlineTimestamp) => false;
}

class MockCreationFixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final createdAt = processStart.add(Duration(milliseconds: 300));

  late final options = defaultTestOptions()..clock = () => createdAt;

  late final hub = MockHub();
  late final root = _FinalTimeoutFailingTracer();
  late final firstFrameBarrier = MockSentrySpan();
  late final pluginRegistrationChild = MockSentrySpan();
  late final sentrySetupChild = MockSentrySpan();

  late final data = AppStartData(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: pluginRegistration,
    sentrySetupTimestamp: sentrySetup,
    phases: [
      AppStartPhase(
        operation: SentrySpanOperations.appStartPluginRegistration,
        description: 'App start to plugin registration',
        startTimestamp: processStart,
        endTimestamp: pluginRegistration,
      ),
      AppStartPhase(
        operation: SentrySpanOperations.appStartSentrySetup,
        description: 'Before Sentry Init Setup',
        startTimestamp: pluginRegistration,
        endTimestamp: sentrySetup,
      ),
    ],
  );

  MockCreationFixture() {
    when(hub.options).thenReturn(options);
    when(
      hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: anyNamed('waitForChildren'),
        autoFinishAfter: anyNamed('autoFinishAfter'),
        bindToScope: anyNamed('bindToScope'),
        trimEnd: anyNamed('trimEnd'),
        onFinish: anyNamed('onFinish'),
      ),
    ).thenReturn(root);

    when(root.samplingDecision).thenReturn(SentryTracesSamplingDecision(true));
    when(root.finish(
      status: anyNamed('status'),
      endTimestamp: anyNamed('endTimestamp'),
      hint: anyNamed('hint'),
    )).thenAnswer((_) async {});

    when(firstFrameBarrier.samplingDecision)
        .thenReturn(SentryTracesSamplingDecision(true));
    when(firstFrameBarrier.finished).thenReturn(false);
    when(firstFrameBarrier.finish(
      status: anyNamed('status'),
      endTimestamp: anyNamed('endTimestamp'),
      hint: anyNamed('hint'),
    )).thenAnswer((_) async {});

    for (final child in [pluginRegistrationChild, sentrySetupChild]) {
      when(child.finished).thenReturn(false);
      when(child.finish(
        status: anyNamed('status'),
        endTimestamp: anyNamed('endTimestamp'),
        hint: anyNamed('hint'),
      )).thenAnswer((_) async {});
    }

    when(
      root.startChild(
        any,
        description: anyNamed('description'),
        startTimestamp: anyNamed('startTimestamp'),
      ),
    ).thenAnswer((invocation) {
      final operation = invocation.positionalArguments.first as String;
      return switch (operation) {
        SentrySpanOperations.appStartFirstFrameRender => firstFrameBarrier,
        SentrySpanOperations.appStartPluginRegistration =>
          pluginRegistrationChild,
        SentrySpanOperations.appStartSentrySetup => sentrySetupChild,
        _ => throw StateError('Unexpected child operation: $operation'),
      };
    });
  }
}

class MockChildFlushFailureFixture extends MockCreationFixture {
  MockChildFlushFailureFixture() : super() {
    when(pluginRegistrationChild.finish(
      status: anyNamed('status'),
      endTimestamp: anyNamed('endTimestamp'),
      hint: anyNamed('hint'),
    )).thenAnswer((invocation) {
      final endTimestamp =
          invocation.namedArguments[#endTimestamp] as DateTime?;
      if (endTimestamp == null) {
        return Future<void>.error(StateError('cleanup failed'));
      }
      return Future<void>.value();
    });
  }
}

class MockPhaseCreationFailureFixture extends MockCreationFixture {
  MockPhaseCreationFailureFixture() : super() {
    when(
      root.startChild(
        any,
        description: anyNamed('description'),
        startTimestamp: anyNamed('startTimestamp'),
      ),
    ).thenAnswer((invocation) {
      final operation = invocation.positionalArguments.first as String;
      return switch (operation) {
        SentrySpanOperations.appStartFirstFrameRender => firstFrameBarrier,
        SentrySpanOperations.appStartPluginRegistration =>
          pluginRegistrationChild,
        SentrySpanOperations.appStartSentrySetup =>
          throw StateError('failed to start $operation'),
        _ => throw StateError('Unexpected child operation: $operation'),
      };
    });
  }
}
