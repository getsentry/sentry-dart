// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/thread_info_integration.dart';
import 'package:sentry_flutter/src/app_start/app_start_result.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
import 'package:sentry_flutter/src/app_start/standalone/static_app_start_trace.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';
import '../first_frame_timing.dart';

void main() {
  group('$StaticAppStartTrace', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('retains app start when the span budget is exhausted', () {
      fakeAsync((async) {
        fixture.options.maxSpans = 2;
        final sut = fixture.getSut()!;
        sut.recordInitEnd(fixture.initEnd);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(fixture.root!.tracer.finished, isFalse);
        sut.recordFirstFrame(fixture.appStartResult);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(fixture.root!.tracer.measurements['app_start_cold']?.value, 350);
        expect(fixture.root!.tracer.endTimestamp, fixture.naturalEnd);
        expect(
          fixture.child('Sentry Initialization').endTimestamp,
          fixture.initEnd,
        );
      });
    });

    test('encodes the standalone root after natural end', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      fixture.completeStartup(sut);
      await pumpEventQueue(times: 10);
      await root.finish(endTimestamp: fixture.rootFinish);

      expect(root.name, 'App Start');
      expect(root.context.operation, 'app.start');
      expect(root.origin, 'auto.app.start');
      expect(root.measurements['app_start_cold']?.value, 350);
      expect(root.data['app.vitals.start.type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    test(
      'stamps the screen resolved at the first frame, not at child creation',
      () async {
        var screen = 'root /';
        final sut = fixture.getSut(startScreenNameProvider: () => screen)!;
        final root = fixture.root!.tracer;
        expect(sut.tryExtend(fixture.processStart), isTrue);
        final extension = sut.extendedSpan as SentrySpan;
        final child = extension.startChild('extended child') as SentrySpan;
        screen = 'launch';

        fixture.completeStartup(sut);
        await pumpEventQueue(times: 10);
        await sut.finishExtended(
          fixture.processStart.add(const Duration(milliseconds: 600)),
        );
        await child.finish(
          endTimestamp: fixture.processStart.add(
            const Duration(milliseconds: 700),
          ),
        );
        await root.finish(endTimestamp: fixture.rootFinish);

        expect(root.data['app.vitals.start.screen'], 'launch');
        expect(
          root.children.map((span) => span.data['app.vitals.start.screen']),
          everyElement('launch'),
        );
        expect(
          root.children.map((span) => span.data['app.vitals.start.type']),
          everyElement('cold'),
        );
      },
    );

    test('creates direct standalone breakdown children', () {
      fixture.getSut();
      final root = fixture.root!.tracer;

      expect(root.children, hasLength(2));
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

      final extension = sut.extendedSpan as SentrySpan;
      expect(extension.context.operation, 'app.start.extended');
      expect(extension.context.description, 'Extended App Start');
      expect(extension.origin, 'auto.app.start');
      expect(extension.status, isNull);
      expect(extension.startTimestamp, extensionStart);
      expect(sut.extendedSpanV2, isNull);
      expect(sut.tryExtend(extensionStart), isFalse);
    });

    test('rejects extension after the first frame', () {
      final sut = fixture.getSut()!;
      fixture.completeStartup(sut);

      expect(
        sut.tryExtend(fixture.processStart.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(sut.extendedSpan, isNull);
    });

    test('leaves open extension descendants running', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpan as SentrySpan;
      final child =
          extension.startChild(
                'extended child',
                startTimestamp: extensionStart.add(
                  const Duration(milliseconds: 1),
                ),
              )
              as SentrySpan;
      final grandchild =
          child.startChild(
                'extended grandchild',
                startTimestamp: extensionStart.add(
                  const Duration(milliseconds: 2),
                ),
              )
              as SentrySpan;
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
      final child =
          extension.startChild(
                'extended child',
                startTimestamp: extensionStart.add(
                  const Duration(milliseconds: 1),
                ),
              )
              as SentrySpan;
      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await extension.finish(endTimestamp: extensionEnd);

      expect(child.finished, isFalse);
      expect(child.endTimestamp, isNull);
      expect(extension.status, SpanStatus.ok());
      expect(extension.endTimestamp, extensionEnd);
    });

    testWidgets('finishes direct extension descendants at the final deadline', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;

      fixture.completeStartup(sut);
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

    test(
      'direct extension finish normalizes its status to successful',
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
      },
    );

    test('swallows extension finish callback failures', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((event) {
        if (identical(event.span, extension)) {
          throw StateError('extension finish failed');
        }
      });

      await expectLater(
        sut.finishExtended(extensionStart.add(const Duration(seconds: 1))),
        completes,
      );

      expect(extension.finished, isTrue);
    });

    test('returns null after the extension finishes', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await sut.finishExtended(extensionEnd);

      expect(sut.extendedSpan, isNull);
    });

    test('preserves finished extension descendants', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpan as SentrySpan;
      final child =
          extension.startChild(
                'extended child',
                startTimestamp: extensionStart.add(
                  const Duration(milliseconds: 1),
                ),
              )
              as SentrySpan;
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

    testWidgets('finishes open extension descendants at the final deadline', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;

      fixture.completeStartup(sut);
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

      fixture.completeStartup(sut);
      await sut.finishExtended(extensionEnd);
      await fixture.root!.tracer.finish(endTimestamp: fixture.rootFinish);
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
      fixture.completeStartup(sut);
      await fixture.root!.tracer.finish(endTimestamp: fixture.rootFinish);
      await pumpEventQueue(times: 10);

      expect(fixture.root!.tracer.measurements['app_start_cold']?.value, 350);
      expect(fixture.root!.tracer.endTimestamp, fixture.naturalEnd);
    });

    test(
      'measures the direct extension endpoint when finish is also requested',
      () async {
        final sut = fixture.getSut()!;
        final extensionStart = fixture.processStart.add(
          const Duration(milliseconds: 400),
        );
        SentrySpan? extension;
        final onSpanFinishBlocker = Completer<void>();
        fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((
          event,
        ) async {
          if (identical(event.span, extension)) {
            await onSpanFinishBlocker.future;
          }
        });
        expect(sut.tryExtend(extensionStart), isTrue);

        extension = sut.extendedSpan as SentrySpan;
        final directEnd = extensionStart.add(const Duration(seconds: 1));
        final laterEnd = extensionStart.add(const Duration(seconds: 2));
        final directFinish = extension.finish(endTimestamp: directEnd);

        await sut.finishExtended(laterEnd);
        onSpanFinishBlocker.complete();
        await directFinish;
        fixture.completeStartup(sut);
        await fixture.root!.tracer.finish(endTimestamp: fixture.rootFinish);
        await pumpEventQueue(times: 10);

        expect(
          fixture.root!.tracer.measurements['app_start_cold']?.value,
          1400.0,
        );
      },
    );

    test('ignores later unrelated root children for measurement', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      final extensionEnd = fixture.processStart.add(
        const Duration(milliseconds: 600),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      fixture.completeStartup(sut);
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

    test('opens Sentry Initialization when init starts', () {
      fixture.getSut();
      final sentryInit = fixture.child('Sentry Initialization');

      expect(sentryInit.context.operation, 'app.start.sentry_init');
      expect(sentryInit.origin, 'auto.app.start');
      expect(sentryInit.startTimestamp, fixture.sentrySetup);
      expect(sentryInit.finished, isFalse);
    });

    test(
      'emits recorded framework and raster intervals as sibling spans',
      () async {
        final threadInfo = ThreadInfoIntegration();
        threadInfo.call(fixture.hub, fixture.options);
        addTearDown(threadInfo.close);
        final sut = fixture.getSut()!;
        final result = fixture.appStartResult.withFrameworkIntervals([
          AppStartRecordedInterval(
            description: 'Root Widget Attachment',
            operation: SentrySpanOperations.appStartRootWidgetAttachment,
            startTimestamp: fixture.sentrySetup,
            endTimestamp: fixture.initEnd,
          ),
          AppStartRecordedInterval(
            description: 'Frame Build',
            operation: SentrySpanOperations.appStartFrameBuild,
            startTimestamp: fixture.initEnd,
            endTimestamp:
                fixture.appStartResult.intervals.single.startTimestamp,
            data: {'flutter.frame.deferred': true},
          ),
        ]);
        sut.recordInitEnd(fixture.initEnd);
        sut.recordFirstFrame(result);
        await pumpEventQueue(times: 10);
        final build = fixture.child('Frame Build');
        expect(build.context.parentSpanId, fixture.root!.context.spanId);
        expect(build.data['flutter.frame.deferred'], isTrue);
        for (final name in ['Root Widget Attachment', 'Frame Build']) {
          final span = fixture.child(name);
          expect(span.data['thread.name'], 'main');
          expect(span.data['thread.id'], 'main'.hashCode.toString());
        }
        final raster = fixture.child('Frame Rasterization');
        expect(raster.data.containsKey('thread.name'), isFalse);
        expect(raster.data.containsKey('thread.id'), isFalse);
        expect(
          fixture.child('Frame Rasterization').startTimestamp,
          fixture.appStartResult.intervals.single.startTimestamp,
        );
        expect(
          fixture.child('Frame Rasterization').endTimestamp,
          fixture.naturalEnd,
        );
        expect(
          fixture.root!.tracer.children.map((span) => span.context.description),
          unorderedEquals([
            'Pre-Init Startup',
            'Sentry Initialization',
            'Root Widget Attachment',
            'Frame Build',
            'Frame Rasterization',
          ]),
        );
      },
    );

    test('does not fabricate build spans from engine timing', () async {
      final sut = fixture.getSut()!;
      fixture.completeStartup(sut);
      await pumpEventQueue(times: 10);
      expect(
        fixture.root!.tracer.children.map((span) => span.context.description),
        isNot(contains('Frame Build')),
      );
      expect(fixture.child('Frame Rasterization').finished, isTrue);
      expect(fixture.root!.tracer.finished, isFalse);
    });

    test(
      'keeps the raster measurement when initialization ends later',
      () async {
        final sut = fixture.getSut()!;
        final lateInit = fixture.naturalEnd.add(
          const Duration(milliseconds: 20),
        );
        sut.recordFirstFrame(fixture.appStartResult);
        sut.recordInitEnd(lateInit);
        await fixture.root!.tracer.finish(endTimestamp: fixture.rootFinish);
        await pumpEventQueue(times: 10);
        expect(fixture.child('Sentry Initialization').endTimestamp, lateInit);
        expect(fixture.root!.tracer.endTimestamp, lateInit);
        expect(fixture.root!.tracer.measurements['app_start_cold']?.value, 350);
      },
    );

    test(
      'ends initialization independently of first-frame reporting',
      () async {
        final sut = fixture.getSut()!;
        sut.recordFirstFrame(fixture.appStartResult);
        sut.recordInitEnd(fixture.initEnd);
        await pumpEventQueue(times: 10);
        expect(
          fixture.child('Sentry Initialization').endTimestamp,
          fixture.initEnd,
        );
      },
    );

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
      expect(root.data['app.vitals.start.type'], 'cold');
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
      'returns null and finishes the root when sentry init span creation fails',
      () async {
        final trace = fixture.getSut(
          timing: fixture.withFirstFrameBeforeProcessStart(),
        );
        await pumpEventQueue(times: 10);

        expect(trace, isNull);
        expect(fixture.root?.tracer.finished, isTrue);
      },
    );

    test('returns null when trace creation fails', () {
      fixture.options
        ..tracesSampleRate = null
        ..tracesSampler = (_) => throw StateError('sampling failed');

      expect(fixture.getSut(), isNull);
    });

    test('when closing flushes the open root', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await sut.close();
      await pumpEventQueue(times: 10);

      expect(root.finished, isTrue);
      expect(root.data['app.vitals.start.type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    test('when closing finishes an open extension before the root', () async {
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

    test('when closing measures the app start to the first frame', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );

      fixture.completeStartup(sut);
      // Closing force-ends the extension long after the first frame, and that
      // endpoint must not become the app start's.
      fixture.clock = fixture.processStart.add(const Duration(seconds: 5));
      await sut.close();
      await pumpEventQueue(times: 10);

      expect(root.measurements['app_start_cold']?.value, 350);
    });

    test('when closing flushes root-owned children', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      final child = root.startChild('late child');

      await sut.close();

      expect(child.finished, isTrue);
      expect(root.finished, isTrue);
    });

    test(
      'when closing drains an extension subtree from the bottom up',
      () async {
        final sut = fixture.getSut()!;
        expect(
          sut.tryExtend(
            fixture.processStart.add(const Duration(milliseconds: 400)),
          ),
          isTrue,
        );
        final extension = sut.extendedSpan as SentrySpan;
        final child = extension.startChild('extended child') as SentrySpan;
        final grandchild =
            child.startChild('extended grandchild') as SentrySpan;
        final finishOrder = <SpanId>[];
        fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((
          event,
        ) {
          final span = event.span;
          if (span is SentrySpan &&
              (identical(span, extension) ||
                  identical(span, child) ||
                  identical(span, grandchild) ||
                  identical(span, fixture.root))) {
            finishOrder.add(span.context.spanId);
          }
        });

        await sut.close();

        // The extension goes first — closing settles it before the root is
        // flushed — and the rest of the subtree then drains child-last.
        expect(finishOrder, [
          extension.context.spanId,
          grandchild.context.spanId,
          child.context.spanId,
          fixture.root!.context.spanId,
        ]);
      },
    );

    testWidgets('waits for idle timeout after natural end', (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await tester.pump(Duration(seconds: 2));
      fixture.completeStartup(sut);
      await tester.pump(Duration(seconds: 1));

      expect(root.finished, isFalse);

      await tester.pump(Duration(seconds: 2));
      await tester.pump();

      expect(root.finished, isTrue);
    });

    testWidgets('restarts idle timeout after a late first frame', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await tester.pump(Duration(seconds: 4));
      fixture.completeStartup(sut);
      await tester.pump();

      expect(root.finished, isFalse);

      await tester.pump(Duration(seconds: 3));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.measurements['app_start_cold']?.value, 350);
    });

    testWidgets('finishes unfinished spans at the final deadline', (
      tester,
    ) async {
      fixture.getSut();
      final root = fixture.root!.tracer;
      final sentryInit = fixture.child('Sentry Initialization');
      final deadline = fixture.createdAt.add(Duration(seconds: 30));

      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, SpanStatus.deadlineExceeded());
      expect(root.endTimestamp, deadline);
      expect(sentryInit.finished, isTrue);
      expect(sentryInit.status, SpanStatus.deadlineExceeded());
      expect(sentryInit.endTimestamp, deadline);
      expect(root.measurements['app_start_cold'], isNull);
    });

    testWidgets('handles children added by deadline finish callbacks', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      final child = extension.startChild('extended child') as SentrySpan;
      final grandchild = child.startChild('extended grandchild') as SentrySpan;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((
        event,
      ) async {
        if (identical(event.span, grandchild)) {
          final lateChild = extension.startChild('late child');
          await lateChild.finish(
            status: SpanStatus.deadlineExceeded(),
            endTimestamp: fixture.createdAt.add(const Duration(seconds: 30)),
          );
        }
      });

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, SpanStatus.deadlineExceeded());
    });

    testWidgets('finishes root-owned children at the final deadline', (
      tester,
    ) async {
      fixture.getSut();
      final root = fixture.root!.tracer;
      final child = root.startChild('late child') as SentrySpan;
      final grandchild = child.startChild('late grandchild') as SentrySpan;
      final deadline = fixture.createdAt.add(const Duration(seconds: 30));

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      for (final span in [child, grandchild]) {
        expect(span.status, SpanStatus.deadlineExceeded());
        expect(span.endTimestamp, deadline);
      }
      expect(root.finished, isTrue);
    });

    testWidgets('rejects extension during deadline finalization', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      var extensionAccepted = false;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((event) {
        if (event.span.context.operation ==
            SentrySpanOperations.appStartFrameRaster) {
          extensionAccepted = sut.tryExtend(fixture.createdAt);
        }
      });

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(extensionAccepted, isFalse);
      expect(fixture.root!.tracer.finished, isTrue);
    });

    testWidgets('ignores extension finish during deadline finalization', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((
        event,
      ) async {
        if (event.span.context.operation ==
            SentrySpanOperations.appStartExtended) {
          await sut.finishExtended(
            extensionStart.add(const Duration(seconds: 1)),
          );
        }
      });
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpan as SentrySpan;

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(extension.status, SpanStatus.deadlineExceeded());
    });

    testWidgets('when closing preserves extension deadline status', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      expect(sut.tryExtend(fixture.createdAt), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      Future<void>? closeFuture;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((event) {
        if (identical(event.span, extension)) {
          closeFuture = sut.close();
        }
      });

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      await closeFuture;

      expect(extension.status, SpanStatus.deadlineExceeded());
    });

    testWidgets('when closing before the extension drains keeps the deadline', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      expect(sut.tryExtend(fixture.createdAt), isTrue);
      final extension = sut.extendedSpan as SentrySpan;
      // The drain walks descendants first, so closing from the child's finish
      // callback reaches the extension while it is still open.
      final child = extension.startChild('extended child') as SentrySpan;
      Future<void>? closeFuture;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanFinish>((event) {
        if (identical(event.span, child)) {
          closeFuture = sut.close();
        }
      });

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await closeFuture;

      expect(extension.status, SpanStatus.deadlineExceeded());
      expect(fixture.root!.tracer.status, SpanStatus.deadlineExceeded());
    });

    testWidgets('finishes the root once at the final deadline', (tester) async {
      final mockFixture = MockCreationFixture();
      final deadline = mockFixture.createdAt.add(Duration(seconds: 30));

      StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        timing: mockFixture.timing,
        startScreenNameProvider: () => 'root /',
      );
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      verify(
        mockFixture.root.finish(
          status: SpanStatus.deadlineExceeded(),
          endTimestamp: deadline,
        ),
      ).called(1);
    });

    testWidgets('omits measurement without a first frame at the deadline', (
      tester,
    ) async {
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
      expect(root.data['app.vitals.start.type'], 'cold');
      expect(root.data['app.vitals.start.screen'], 'root /');
    });

    testWidgets(
      'measures to the first frame when the extension never finished',
      (tester) async {
        final sut = fixture.getSut()!;
        final root = fixture.root!.tracer;
        expect(
          sut.tryExtend(
            fixture.processStart.add(const Duration(milliseconds: 400)),
          ),
          isTrue,
        );

        fixture.completeStartup(sut);
        await tester.pump(Duration(seconds: 30));
        await tester.pump();

        expect(root.status, SpanStatus.deadlineExceeded());
        expect(root.measurements['app_start_cold']?.value, 350);
      },
    );

    testWidgets('keeps the extension endpoint when a descendant deadlines', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
      final extension = sut.extendedSpan as SentrySpan;
      extension.startChild('extended child');

      fixture.completeStartup(sut);
      await sut.finishExtended(
        fixture.processStart.add(const Duration(milliseconds: 600)),
      );
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(root.status, SpanStatus.deadlineExceeded());
      expect(root.measurements['app_start_cold']?.value, 600);
    });

    testWidgets('marks an unfinished extension subtree deadline exceeded', (
      tester,
    ) async {
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

    testWidgets('when closing cancels the final deadline', (tester) async {
      final sut = fixture.getSut()!;
      final root = fixture.root!.tracer;

      await sut.close();
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(root.finished, isTrue);
      expect(root.status, isNull);
    });

    test('when closing flushes only the children still open', () async {
      final mockFixture = MockCreationFixture();
      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        timing: mockFixture.timing,
        startScreenNameProvider: () => 'root /',
      )!;

      await trace.close();

      verify(mockFixture.sentryInitChild.finish()).called(1);
      // The phase child was finished while the trace was built, so the flush
      // must leave it alone.
      verify(
        mockFixture.preInitChild.finish(endTimestamp: mockFixture.sentrySetup),
      ).called(1);
      verifyNever(mockFixture.preInitChild.finish());
      verify(mockFixture.root.finish()).called(1);
    });

    test('creates trace without tracer deadline coordination', () {
      final mockFixture = MockCreationFixture();

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        timing: mockFixture.timing,
        startScreenNameProvider: () => 'root /',
      );
      // Otherwise the 30s final-timeout timer outlives the test.
      addTearDown(() => trace?.close());

      expect(trace, isNotNull);
    });

    testWidgets('swallows final deadline failures', (tester) async {
      final mockFixture = MockDeadlineFailureFixture();
      final deadline = mockFixture.createdAt.add(Duration(seconds: 30));

      final trace = StaticAppStartTrace.tryCreate(
        hub: mockFixture.hub,
        timing: mockFixture.timing,
        startScreenNameProvider: () => 'root /',
      );
      await tester.pump(Duration(seconds: 30));
      await tester.pump();

      expect(trace, isNotNull);
      verify(
        mockFixture.root.finish(
          status: SpanStatus.deadlineExceeded(),
          endTimestamp: deadline,
        ),
      ).called(1);
    });

    test(
      'returns null and flushes created spans when phase creation throws',
      () async {
        final mockFixture = MockPhaseCreationFailureFixture();

        final trace = StaticAppStartTrace.tryCreate(
          hub: mockFixture.hub,
          timing: mockFixture.timing,
          startScreenNameProvider: () => 'root /',
        );
        await pumpEventQueue(times: 10);

        expect(trace, isNull);
        verify(mockFixture.sentryInitChild.finish()).called(1);
        verify(mockFixture.root.finish()).called(1);
      },
    );
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final naturalEnd = processStart.add(Duration(milliseconds: 350));
  late final rootFinish = processStart.add(Duration(milliseconds: 500));
  late final createdAt = processStart.add(Duration(milliseconds: 300));
  SentrySpan? root;

  /// What `options.clock` reads, so a test can move time on after creation.
  late DateTime clock = createdAt;

  final transport = _FakeTransport();

  late final options = defaultTestOptions()
    ..transport = transport
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.static
    ..clock = () => clock;
  late final hub = Hub(options);
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final timing = AppStartTiming(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    sentrySetupTimestamp: sentrySetup,
    intervals: [
      AppStartRecordedInterval(
        operation: SentrySpanOperations.appStartPreInit,
        description: 'Pre-Init Startup',
        startTimestamp: processStart,
        endTimestamp: sentrySetup,
      ),
    ],
  );

  late final initEnd = processStart.add(Duration(milliseconds: 220));

  /// Engine frame timing that starts after [initEnd] and
  /// rasterizes at [naturalEnd].
  late final appStartResult = AppStartResult.tryResolveRasterTiming(
    fakeFirstFrameTiming(
      vsyncStart: processStart.add(Duration(milliseconds: 250)),
      buildStart: processStart.add(Duration(milliseconds: 260)),
      buildFinish: processStart.add(Duration(milliseconds: 300)),
      rasterStart: processStart.add(Duration(milliseconds: 310)),
      rasterFinish: naturalEnd,
    ),
  )!;

  AppStartTiming withFirstFrameBeforeProcessStart() {
    return AppStartTiming(
      type: timing.type,
      processStartTimestamp: processStart,
      sentrySetupTimestamp: processStart.subtract(Duration(milliseconds: 1)),
      intervals: timing.intervals,
    );
  }

  /// Drives the whole startup in production order: init ends, then the first
  /// frame renders. `Sentry Initialization` stays open until init ends, so a
  /// test that only records the frame never lets the root report.
  void completeStartup(StaticAppStartTrace sut) {
    sut.recordInitEnd(initEnd);
    sut.recordFirstFrame(appStartResult);
  }

  /// The root child named [description], which must be unique.
  SentrySpan child(String description) => root!.tracer.children.singleWhere(
    (span) => span.context.description == description,
  );

  StaticAppStartTrace? getSut({
    AppStartTiming? timing,
    String Function()? startScreenNameProvider,
  }) {
    options.lifecycleRegistry.registerCallback<OnSpanStart>((event) {
      final span = event.span;
      if (span is SentrySpan && span.isRootSpan) root ??= span;
    });
    final trace = StaticAppStartTrace.tryCreate(
      hub: hub,
      timing: timing ?? this.timing,
      startScreenNameProvider: startScreenNameProvider ?? () => 'root /',
    );
    // Otherwise the 30s final-timeout timer outlives the test.
    addTearDown(() => trace?.close());
    return trace;
  }
}

class _FakeTransport implements Transport {
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async => SentryId.empty();
}

class MockCreationFixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final createdAt = processStart.add(Duration(milliseconds: 300));

  late final options = defaultTestOptions()..clock = () => createdAt;

  late final hub = MockHub();
  late final root = MockSentryTracer();
  late final sentryInitChild = MockSentrySpan();
  late final preInitChild = MockSentrySpan();

  late final timing = AppStartTiming(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    sentrySetupTimestamp: sentrySetup,
    intervals: [
      AppStartRecordedInterval(
        operation: SentrySpanOperations.appStartPreInit,
        description: 'Pre-Init Startup',
        startTimestamp: processStart,
        endTimestamp: sentrySetup,
      ),
    ],
  );

  MockCreationFixture() {
    when(root.pauseIdleTimeout()).thenAnswer((_) {});
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
    when(
      root.finish(
        status: anyNamed('status'),
        endTimestamp: anyNamed('endTimestamp'),
        hint: anyNamed('hint'),
      ),
    ).thenAnswer((_) async {});

    when(
      sentryInitChild.samplingDecision,
    ).thenReturn(SentryTracesSamplingDecision(true));

    // `finished` has to follow `finish()` the way a real span does, otherwise
    // the `!finished` guards in the trace are never exercised.
    for (final child in [sentryInitChild, preInitChild]) {
      var finished = false;
      when(child.finished).thenAnswer((_) => finished);
      when(
        child.finish(
          status: anyNamed('status'),
          endTimestamp: anyNamed('endTimestamp'),
          hint: anyNamed('hint'),
        ),
      ).thenAnswer((_) async {
        finished = true;
      });
    }
    when(root.children).thenReturn([sentryInitChild, preInitChild]);

    when(
      root.startChild(
        any,
        description: anyNamed('description'),
        startTimestamp: anyNamed('startTimestamp'),
      ),
    ).thenAnswer((invocation) {
      final operation = invocation.positionalArguments.first as String;
      return switch (operation) {
        SentrySpanOperations.appStartSentryInit => sentryInitChild,
        SentrySpanOperations.appStartPreInit => preInitChild,
        _ => throw StateError('Unexpected child operation: $operation'),
      };
    });
  }
}

class MockDeadlineFailureFixture extends MockCreationFixture {
  MockDeadlineFailureFixture() : super() {
    when(
      root.finish(
        status: SpanStatus.deadlineExceeded(),
        endTimestamp: createdAt.add(Duration(seconds: 30)),
      ),
    ).thenAnswer((_) => Future<void>.error(StateError('deadline failed')));
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
        SentrySpanOperations.appStartSentryInit => sentryInitChild,
        SentrySpanOperations.appStartPreInit => throw StateError(
          'failed to start $operation',
        ),
        _ => throw StateError('Unexpected child operation: $operation'),
      };
    });
  }
}
