// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_data.dart';
import 'package:sentry_flutter/src/app_start/standalone/app_start_trace.dart';
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

    test('creates one extended app-start span before first frame', () {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );

      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpan;
      expect(extension, isA<SentrySpan>());
      expect(
          extension.context.operation, SentrySpanOperations.appStartExtended);
      expect(extension.context.description, standaloneExtendedAppStartName);
      expect(extension.origin, SentryTraceOrigins.autoAppStart);
      expect(extension.status, SpanStatus.ok());
      expect(extension.startTimestamp, extensionStart);
      expect(sut.extendedSpanV2, isA<NoOpSentrySpanV2>());
      expect(sut.tryExtend(extensionStart), isFalse);
    });

    test('rejects extension after the first frame', () {
      final sut = fixture.getSut()!;
      sut.recordFirstFrame(fixture.naturalEnd);

      expect(
        sut.tryExtend(fixture.processStart.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(sut.extendedSpan, isA<NoOpSentrySpan>());
    });

    test('leaves open extension descendants running', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild(
        'extended child',
        startTimestamp: extensionStart.add(const Duration(milliseconds: 1)),
      ) as SentrySpan;
      final grandchild = child.startChild(
        'extended grandchild',
        startTimestamp: extensionStart.add(const Duration(milliseconds: 2)),
      ) as SentrySpan;
      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await sut.finishExtended(extensionEnd);

      expect(grandchild.finished, isFalse);
      expect(child.finished, isFalse);
      expect(extension.status, SpanStatus.ok());
      expect(grandchild.endTimestamp, isNull);
      expect(child.endTimestamp, isNull);
      expect(extension.endTimestamp, extensionEnd);
    });

    test('direct extension finish leaves open descendants running', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild(
        'extended child',
        startTimestamp: extensionStart.add(const Duration(milliseconds: 1)),
      ) as SentrySpan;
      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await extension.finish(endTimestamp: extensionEnd);

      expect(child.finished, isFalse);
      expect(child.endTimestamp, isNull);
      expect(extension.status, SpanStatus.ok());
      expect(extension.endTimestamp, extensionEnd);
    });

    testWidgets('finishes direct extension descendants at the final deadline',
        (tester) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;

      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await extension.finish(
        endTimestamp: extensionStart.add(const Duration(seconds: 1)),
      );
      expect(child.finished, isFalse);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(child.finished, isTrue);
      expect(child.status, SpanStatus.deadlineExceeded());
      expect(fixture.root!.tracer.status, SpanStatus.deadlineExceeded());
    });

    test('direct extension finish normalizes its status to successful',
        () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;

      await extension.finish(
        status: SpanStatus.internalError(),
        endTimestamp: extensionStart.add(const Duration(seconds: 1)),
      );

      expect(extension.status, SpanStatus.ok());
    });

    test('returns a no-op extended span after the extension finishes',
        () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await sut.finishExtended(extensionEnd);

      expect(sut.extendedSpan, isA<NoOpSentrySpan>());
    });

    test('preserves finished extension descendants', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild(
        'extended child',
        startTimestamp: extensionStart.add(const Duration(milliseconds: 1)),
      ) as SentrySpan;
      final childEnd = extensionStart.add(const Duration(milliseconds: 500));
      await child.finish(
        status: SpanStatus.internalError(),
        endTimestamp: childEnd,
      );
      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await sut.finishExtended(extensionEnd);

      expect(child.status, SpanStatus.internalError());
      expect(child.endTimestamp, childEnd);
    });

    test('does not finish the root when the extension finishes', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      await sut.finishExtended(extensionStart.add(const Duration(seconds: 1)));

      expect(fixture.root!.tracer.finished, isFalse);
    });

    test('reuses the first asynchronous extension completion', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;

      final first = sut.finishExtended(
        extensionStart.add(const Duration(seconds: 1)),
      );
      final second = sut.finishExtended(
        extensionStart.add(const Duration(seconds: 2)),
      );

      expect(second, same(first));
      await first;
      expect(
        extension.endTimestamp,
        extensionStart.add(const Duration(seconds: 1)),
      );
    });

    testWidgets('finishes open extension descendants at the final deadline',
        (tester) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;

      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await sut.finishExtended(extensionStart.add(const Duration(seconds: 1)));
      expect(child.finished, isFalse);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(child.finished, isTrue);
      expect(child.status, SpanStatus.deadlineExceeded());
      expect(fixture.root!.tracer.status, SpanStatus.deadlineExceeded());
    });

    test('measures the extension endpoint after the first frame', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      final extensionEnd = fixture.processStart.add(
        const Duration(milliseconds: 600),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await sut.finishExtended(extensionEnd);
      await fixture.root!.tracer.finish(
        endTimestamp: fixture.rootFinish,
      );
      await pumpEventQueue(times: 10);

      expect(fixture.root!.tracer.measurements['app_start_cold']?.value, 600);
    });

    test('keeps the natural endpoint when the extension ends first', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 200),
      );
      final extensionEnd = fixture.processStart.add(
        const Duration(milliseconds: 250),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      await sut.finishExtended(extensionEnd);
      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await fixture.root!.tracer.finish(endTimestamp: fixture.rootFinish);
      await pumpEventQueue(times: 10);

      expect(fixture.root!.tracer.measurements['app_start_cold']?.value, 350);
    });

    test('ignores later unrelated root children for measurement', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      final extensionEnd = fixture.processStart.add(
        const Duration(milliseconds: 600),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      sut.recordFirstFrame(fixture.naturalEnd);
      sut.finish(fixture.naturalEnd);
      await sut.finishExtended(extensionEnd);
      final unrelated = fixture.root!.tracer.startChild(
        'unrelated child',
        startTimestamp: fixture.processStart.add(
          const Duration(milliseconds: 700),
        ),
      );
      await unrelated.finish(
        endTimestamp: fixture.processStart.add(
          const Duration(milliseconds: 900),
        ),
      );
      await fixture.root!.tracer.finish(
        endTimestamp: fixture.processStart.add(
          const Duration(milliseconds: 1000),
        ),
      );
      await pumpEventQueue(times: 10);

      expect(fixture.root!.tracer.measurements['app_start_cold']?.value, 600);
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

    test('close finishes an open extension before the root', () async {
      final sut = fixture.getSut()!;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
      final extension = sut.extendedSpan as SentrySpan;
      final root = fixture.root!.tracer;

      await sut.close();

      expect(extension.finished, isTrue);
      expect(root.finished, isTrue);
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

    testWidgets('finishes unfinished spans at the final deadline',
        (tester) async {
      fixture.getSut();
      final root = fixture.root!.tracer;
      final firstFrame = root.children.firstWhere(
        (span) => span.context.description == 'First frame render',
      );
      final deadline = fixture.createdAt.add(Duration(seconds: 30));

      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, SpanStatus.deadlineExceeded());
      expect(root.endTimestamp, deadline);
      expect(firstFrame.finished, isTrue);
      expect(firstFrame.status, SpanStatus.deadlineExceeded());
      expect(firstFrame.endTimestamp, deadline);
      expect(root.measurements['app_start_cold'], isNull);
    });

    testWidgets('handles children added by deadline finish callbacks',
        (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;
      final grandchild = child.startChild('extended grandchild') as SentrySpan;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>(
        (event) async {
          if (identical(event.span, grandchild)) {
            final lateChild = extension.startChild('late child');
            await lateChild.finish(
              status: SpanStatus.deadlineExceeded(),
              endTimestamp: fixture.createdAt.add(const Duration(seconds: 30)),
            );
          }
        },
      );

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, SpanStatus.deadlineExceeded());
    });

    testWidgets('finishes the root once at the final deadline', (tester) async {
      final mockFixture = MockCreationFixture();
      final deadline = mockFixture.createdAt.add(Duration(seconds: 30));

      StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      );
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      verify(mockFixture.root.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: deadline,
      )).called(1);
    });

    testWidgets('suppresses measurement for an unfinished extension deadline',
        (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );

      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, SpanStatus.deadlineExceeded());
      expect(root.measurements['app_start_cold'], isNull);
      expect(root.data['app_start_type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    testWidgets('marks an unfinished extension subtree deadline exceeded',
        (tester) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;
      final grandchild = child.startChild('extended grandchild') as SentrySpan;
      final finishOrder = <SpanId>[];
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((event) {
        final span = event.span;
        if (span is SentrySpan &&
            (identical(span, extension) ||
                identical(span, child) ||
                identical(span, grandchild) ||
                identical(span, fixture.root))) {
          finishOrder.add(span.context.spanId);
        }
      });
      final deadline = fixture.createdAt.add(const Duration(seconds: 30));

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      for (final span in [extension, child, grandchild]) {
        expect(span.status, SpanStatus.deadlineExceeded());
        expect(span.endTimestamp, deadline);
      }
      expect(finishOrder, [
        grandchild.context.spanId,
        child.context.spanId,
        extension.context.spanId,
        fixture.root!.context.spanId,
      ]);
    });

    testWidgets('close cancels the final deadline', (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await sut.close();
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, isNull);
    });

    test('close flushes every tracked child', () async {
      final mockFixture = MockCreationFixture();
      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      )!;

      await trace.close();

      verify(mockFixture.firstFrameBarrier.finish()).called(1);
      verify(mockFixture.pluginRegistrationChild.finish(
        status: anyNamed('status'),
        endTimestamp: anyNamed('endTimestamp'),
        hint: anyNamed('hint'),
      )).called(2);
      verify(mockFixture.sentrySetupChild.finish(
        status: anyNamed('status'),
        endTimestamp: anyNamed('endTimestamp'),
        hint: anyNamed('hint'),
      )).called(2);
      verify(mockFixture.root.finish()).called(1);
    });

    test('creates trace without tracer deadline coordination', () {
      final mockFixture = MockCreationFixture();

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      );

      expect(trace, isNotNull);
    });

    testWidgets('swallows final deadline failures', (tester) async {
      final mockFixture = MockDeadlineFailureFixture();
      final deadline = mockFixture.createdAt.add(Duration(seconds: 30));

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        data: mockFixture.data,
        startScreenNameProvider: () => 'root /',
      );
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(trace, isNotNull);
      verify(mockFixture.root.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: deadline,
      )).called(1);
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
  late final createdAt = processStart.add(Duration(milliseconds: 300));
  SentrySpan? root;

  final transport = _FakeTransport();

  late final options = defaultTestOptions()
    ..transport = transport
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.static
    ..clock = () => createdAt;
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

class MockCreationFixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final pluginRegistration = processStart.add(Duration(milliseconds: 100));
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final createdAt = processStart.add(Duration(milliseconds: 300));

  late final options = defaultTestOptions()..clock = () => createdAt;

  late final hub = MockHub();
  late final root = MockSentryTracer();
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
    when(root.children).thenReturn([
      firstFrameBarrier,
      pluginRegistrationChild,
      sentrySetupChild,
    ]);

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

class MockDeadlineFailureFixture extends MockCreationFixture {
  MockDeadlineFailureFixture() : super() {
    when(root.finish(
      status: SpanStatus.deadlineExceeded(),
      endTimestamp: createdAt.add(Duration(seconds: 30)),
    )).thenAnswer((_) => Future<void>.error(StateError('deadline failed')));
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
