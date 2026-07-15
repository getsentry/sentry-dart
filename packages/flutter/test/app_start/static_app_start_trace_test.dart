// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_data.dart';
import 'package:sentry_flutter/src/app_start/static_app_start_trace.dart';

import '../mocks.dart';

void main() {
  group('$StaticAppStartTrace', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('encodes the standalone root after natural end', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      sut.recordNaturalEnd(fixture.naturalEnd);
      await pumpEventQueue(times: 10);
      await root.finish(endTimestamp: fixture.rootFinish);

      expect(root.name, 'App Start');
      expect(root.context.operation, 'app.start');
      expect(root.origin, 'auto.app.start');
      expect(root.measurements['app_start_cold']?.value, 350);
      expect(root.data['app_start_type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
      expect(fixture.completions, 1);
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

    test('abandons an unsampled root', () async {
      fixture.options.tracesSampleRate = 0;

      expect(fixture.getSut(), isNull);
      await pumpEventQueue();

      expect(fixture.root, isNotNull);
      expect(fixture.root!.tracer.finished, isTrue);
    });

    test('returns null when trace creation fails', () {
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (_) => throw StateError('sampling failed');

      expect(fixture.getSut(), isNull);
    });

    testWidgets('waits for idle timeout after natural end', (tester) async {
      final sut = fixture.getSut()!;

      await tester.pump(Duration(seconds: 2));
      sut.recordNaturalEnd(fixture.naturalEnd);
      await tester.pump(Duration(seconds: 1));

      expect(fixture.completions, 0);

      await tester.pump(Duration(seconds: 2));
      await tester.pump();

      expect(fixture.completions, 1);
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final naturalEnd = processStart.add(Duration(milliseconds: 350));
  late final rootFinish = processStart.add(Duration(milliseconds: 500));
  var completions = 0;
  SentrySpan? root;

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.static
    ..clock = () => processStart.add(Duration(milliseconds: 300));
  late final hub = Hub(options);
  late final data = AppStartData(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: processStart.add(Duration(milliseconds: 100)),
    sentrySetupTimestamp: processStart.add(Duration(milliseconds: 200)),
    nativePhaseIntervals: [],
  );

  StaticAppStartTrace? getSut() {
    options.lifecycleRegistry.registerCallback<OnSpanStart>((event) {
      final span = event.span;
      if (span is SentrySpan && span.isRootSpan) root ??= span;
    });
    return StaticAppStartTrace.tryCreate(
      hub: hub,
      data: data,
      onCompleted: () => completions++,
      appStartScreenNameProvider: () => 'root /',
    );
  }
}
