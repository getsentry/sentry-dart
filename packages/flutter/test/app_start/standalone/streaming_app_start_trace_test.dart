// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/thread_info_integration.dart';
import 'package:sentry_flutter/src/app_start/app_start_result.dart';
import 'package:sentry_flutter/src/app_start/app_start_timing.dart';
import 'package:sentry_flutter/src/app_start/standalone/streaming_app_start_trace.dart';

import '../../mocks.dart';
import '../first_frame_timing.dart';

void main() {
  group('$StreamingAppStartTrace', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    testWidgets('waits for the frame when optional spans are ignored', (
      tester,
    ) async {
      fixture.options.ignoreSpans = [
        IgnoreSpanRule.nameEquals('Frame Build'),
        IgnoreSpanRule.nameEquals('Frame Rasterization'),
      ];
      final sut = fixture.getSut()!;
      sut.recordInitEnd(fixture.initEnd);
      await tester.pump(const Duration(seconds: 4));
      expect(fixture.root!.isEnded, isFalse);
      expect(
        fixture.child('Sentry Initialization').endTimestamp,
        fixture.initEnd,
      );
      sut.recordFirstFrame(fixture.appStartResult);
      fixture.root!.end(endTimestamp: fixture.rootFinish);
      await tester.pump();
      expect(fixture.root!.endTimestamp, fixture.naturalEnd);
      expect(fixture.root!.attributes['app.vitals.start.value']?.value, 350.0);
    });

    test('encodes the standalone root after natural end', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;

      fixture.completeStartup(sut);
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

    test(
      'stamps spans captured after the first frame with that screen',
      () async {
        var screen = 'root /';
        final sut = fixture.getSut(startScreenNameProvider: () => screen)!;
        expect(
          sut.tryExtend(
            fixture.processStart.add(const Duration(milliseconds: 400)),
          ),
          isTrue,
        );
        final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
        final child =
            fixture.hub.startInactiveSpan(
                  'extended child',
                  parentSpan: extension,
                )
                as RecordingSentrySpanV2;
        final grandchild =
            fixture.hub.startInactiveSpan(
                  'extended grandchild',
                  parentSpan: child,
                )
                as RecordingSentrySpanV2;
        screen = 'launch';

        fixture.completeStartup(sut);
        await sut.finishExtended(
          fixture.processStart.add(const Duration(milliseconds: 600)),
        );
        child.end(
          endTimestamp: fixture.processStart.add(
            const Duration(milliseconds: 700),
          ),
        );
        grandchild.end(
          endTimestamp: fixture.processStart.add(
            const Duration(milliseconds: 750),
          ),
        );
        fixture.root!.end(endTimestamp: fixture.rootFinish);
        await pumpEventQueue(times: 10);

        expect(
          fixture.root!.attributes['app.vitals.start.screen']?.value,
          'launch',
        );
        expect(
          [
            fixture.child('Frame Rasterization'),
            extension,
            child,
            grandchild,
          ].map((span) => span.attributes['app.vitals.start.screen']?.value),
          everyElement('launch'),
        );
        expect(
          [
            child,
            grandchild,
          ].map((span) => span.attributes['app.vitals.start.type']?.value),
          everyElement('cold'),
        );
        expect(
          fixture
              .child('Pre-Init Startup')
              .attributes['app.vitals.start.screen']
              ?.value,
          'root /',
        );
      },
    );

    test(
      'measures the later extension endpoint instead of the root endpoint',
      () async {
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
        fixture.root!.end(
          endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        );
        await pumpEventQueue(times: 10);

        expect(
          fixture.root!.attributes['app.vitals.start.value']?.value,
          600.0,
        );
        expect(
          fixture.root!.attributes['app.vitals.start.cold.value']?.value,
          600.0,
        );
      },
    );

    test(
      'keeps the natural endpoint above an early extension endpoint',
      () async {
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
        final unrelated =
            fixture.hub.startInactiveSpan(
                  'unrelated child',
                  parentSpan: fixture.root,
                  startTimestamp: fixture.processStart.add(
                    const Duration(milliseconds: 700),
                  ),
                )
                as RecordingSentrySpanV2;
        unrelated.end(
          endTimestamp: fixture.processStart.add(
            const Duration(milliseconds: 900),
          ),
        );
        fixture.root!.end(
          endTimestamp: fixture.processStart.add(const Duration(seconds: 1)),
        );
        await pumpEventQueue(times: 10);

        expect(
          fixture.root!.attributes['app.vitals.start.value']?.value,
          350.0,
        );
      },
    );

    testWidgets('omits duration without a first frame at deadline', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      final root = fixture.root!;
      expect(root.isEnded, isTrue);
      expect(root.status, SentrySpanStatusV2.error);
      expect(root.attributes['app.vitals.start.value'], isNull);
      expect(root.attributes['app.vitals.start.type']?.value, 'cold');
      expect(root.attributes['app.vitals.start.screen']?.value, 'root /');
      expect(extension.status, SentrySpanStatusV2.error);
      expect(
        extension
            .attributes[SemanticAttributesConstants.sentryStatusMessage]
            ?.value,
        'deadline_exceeded',
      );
    });

    testWidgets('measures to the first frame when the extension never ended', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );

      fixture.completeStartup(sut);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      final root = fixture.root!;
      expect(root.status, SentrySpanStatusV2.error);
      expect(root.attributes['app.vitals.start.value']?.value, 350.0);
    });

    testWidgets('keeps the extension endpoint when a descendant deadlines', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      fixture.hub.startInactiveSpan('extended child', parentSpan: extension);

      fixture.completeStartup(sut);
      await sut.finishExtended(
        fixture.processStart.add(const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      final root = fixture.root!;
      expect(root.status, SentrySpanStatusV2.error);
      expect(root.attributes['app.vitals.start.value']?.value, 600.0);
    });

    testWidgets('close preserves extension deadline status', (tester) async {
      final sut = fixture.getSut()!;
      expect(sut.tryExtend(fixture.processStart), isTrue);
      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      Future<void>? closeFuture;
      fixture.options.lifecycleRegistry.registerCallback<OnSpanEndV2>((event) {
        if (identical(event.span, extension)) {
          closeFuture = sut.close();
        }
      });

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(closeFuture, isNotNull);
      await closeFuture;

      expect(extension.status, SentrySpanStatusV2.error);
      expect(
        extension
            .attributes[SemanticAttributesConstants.sentryStatusMessage]
            ?.value,
        'deadline_exceeded',
      );
    });

    test('creates direct standalone breakdown children', () {
      fixture.getSut();

      expect(fixture.children, hasLength(2));
      expect(
        fixture.children.map((span) => span.parentSpan),
        everyElement(same(fixture.root)),
      );
    });

    test('creates one extended app-start span before first frame', () {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );

      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      expect(extension.parentSpan, same(fixture.root));
      expect(
        extension.attributes[SemanticAttributesConstants.sentryOp]?.value,
        'app.start.extended',
      );
      expect(
        extension.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
        'auto.app.start',
      );
      expect(sut.extendedSpan, isNull);
    });

    test('leaves open extension descendants running', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      final child =
          fixture.hub.startInactiveSpan(
                'extended child',
                parentSpan: extension,
                startTimestamp: extensionStart.add(
                  const Duration(milliseconds: 1),
                ),
              )
              as RecordingSentrySpanV2;
      final grandchild =
          fixture.hub.startInactiveSpan(
                'extended grandchild',
                parentSpan: child,
                startTimestamp: extensionStart.add(
                  const Duration(milliseconds: 2),
                ),
              )
              as RecordingSentrySpanV2;
      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await sut.finishExtended(extensionEnd);
      await pumpEventQueue(times: 10);

      expect(grandchild.isEnded, isFalse);
      expect(child.isEnded, isFalse);
      expect(extension.status, SentrySpanStatusV2.ok);
      expect(extension.endTimestamp, extensionEnd);
    });

    testWidgets('finishes open extension descendants at the final deadline', (
      tester,
    ) async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      final child =
          fixture.hub.startInactiveSpan('extended child', parentSpan: extension)
              as RecordingSentrySpanV2;

      fixture.completeStartup(sut);
      await sut.finishExtended(extensionStart.add(const Duration(seconds: 1)));
      expect(child.isEnded, isFalse);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(child.isEnded, isTrue);
      expect(child.status, SentrySpanStatusV2.error);
      expect(
        child
            .attributes[SemanticAttributesConstants.sentryStatusMessage]
            ?.value,
        'deadline_exceeded',
      );
      expect(fixture.root!.status, SentrySpanStatusV2.error);
    });

    test('direct extension end leaves open descendants running', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      final child =
          fixture.hub.startInactiveSpan('extended child', parentSpan: extension)
              as RecordingSentrySpanV2;
      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      extension.end(endTimestamp: extensionEnd);
      await pumpEventQueue(times: 10);

      expect(child.isEnded, isFalse);
      expect(child.endTimestamp, isNull);
      expect(extension.status, SentrySpanStatusV2.ok);
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
      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      final child =
          fixture.hub.startInactiveSpan('extended child', parentSpan: extension)
              as RecordingSentrySpanV2;

      fixture.completeStartup(sut);
      extension.end(
        endTimestamp: extensionStart.add(const Duration(seconds: 1)),
      );
      expect(child.isEnded, isFalse);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(child.isEnded, isTrue);
      expect(child.status, SentrySpanStatusV2.error);
      expect(
        child
            .attributes[SemanticAttributesConstants.sentryStatusMessage]
            ?.value,
        'deadline_exceeded',
      );
      expect(fixture.root!.status, SentrySpanStatusV2.error);
    });

    test('direct extension end normalizes its status to successful', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);
      final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
      extension.status = SentrySpanStatusV2.error;
      fixture.hub.startInactiveSpan('extended child', parentSpan: extension);
      SentrySpanStatusV2? processedStatus;
      fixture.options.lifecycleRegistry.registerCallback<OnProcessSpan>((
        event,
      ) {
        if (identical(event.span, extension)) {
          processedStatus = event.span.status;
        }
      });

      extension.end(
        endTimestamp: extensionStart.add(const Duration(seconds: 1)),
      );
      await pumpEventQueue(times: 10);

      expect(extension.status, SentrySpanStatusV2.ok);
      expect(processedStatus, SentrySpanStatusV2.ok);
    });

    test('returns null after the extension ends', () async {
      final sut = fixture.getSut()!;
      final extensionStart = fixture.processStart.add(
        const Duration(milliseconds: 400),
      );
      expect(sut.tryExtend(extensionStart), isTrue);

      final extensionEnd = extensionStart.add(const Duration(seconds: 1));

      await sut.finishExtended(extensionEnd);

      expect(sut.extendedSpanV2, isNull);
    });

    test(
      'uses the direct extension endpoint when finish is also requested',
      () async {
        final sut = fixture.getSut()!;
        final extensionStart = fixture.processStart.add(
          const Duration(milliseconds: 400),
        );
        expect(sut.tryExtend(extensionStart), isTrue);

        final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
        final child =
            fixture.hub.startInactiveSpan(
                  'extended child',
                  parentSpan: extension,
                )
                as RecordingSentrySpanV2;
        final directEnd = extensionStart.add(const Duration(seconds: 1));
        final laterEnd = extensionStart.add(const Duration(seconds: 2));
        extension.end(endTimestamp: directEnd);

        await sut.finishExtended(laterEnd);
        await pumpEventQueue(times: 10);

        expect(child.isEnded, isFalse);
        expect(extension.endTimestamp, directEnd);
      },
    );

    test(
      'measures the direct extension endpoint when finish is also requested',
      () async {
        final sut = fixture.getSut()!;
        final extensionStart = fixture.processStart.add(
          const Duration(milliseconds: 400),
        );
        RecordingSentrySpanV2? extension;
        final onSpanEndBlocker = Completer<void>();
        fixture.options.lifecycleRegistry.registerCallback<OnSpanEndV2>((
          event,
        ) async {
          if (identical(event.span, extension)) {
            await onSpanEndBlocker.future;
          }
        });
        expect(sut.tryExtend(extensionStart), isTrue);

        extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
        final directEnd = extensionStart.add(const Duration(seconds: 1));
        final laterEnd = extensionStart.add(const Duration(seconds: 2));
        extension.end(endTimestamp: directEnd);

        await sut.finishExtended(laterEnd);
        onSpanEndBlocker.complete();
        fixture.completeStartup(sut);
        fixture.root!.end(endTimestamp: fixture.rootFinish);
        await pumpEventQueue(times: 10);

        expect(
          fixture.root!.attributes['app.vitals.start.value']?.value,
          1400.0,
        );
      },
    );

    test(
      'preserves ended extension descendants and leaves root open',
      () async {
        final sut = fixture.getSut()!;
        final extensionStart = fixture.processStart.add(
          const Duration(milliseconds: 400),
        );
        expect(sut.tryExtend(extensionStart), isTrue);

        final extension = sut.extendedSpanV2 as RecordingSentrySpanV2;
        final child =
            fixture.hub.startInactiveSpan(
                  'extended child',
                  parentSpan: extension,
                )
                as RecordingSentrySpanV2;
        final childEnd = extensionStart.add(const Duration(milliseconds: 500));
        child.status = SentrySpanStatusV2.error;
        child.end(endTimestamp: childEnd);
        await pumpEventQueue(times: 10);

        final extensionEnd = extensionStart.add(const Duration(seconds: 1));
        await sut.finishExtended(extensionEnd);
        await pumpEventQueue(times: 10);

        expect(child.status, SentrySpanStatusV2.error);
        expect(child.endTimestamp, childEnd);
        expect(extension.endTimestamp, extensionEnd);
        expect(fixture.root!.isEnded, isFalse);
      },
    );

    test('opens Sentry Initialization when init starts', () {
      fixture.getSut();
      final sentryInit = fixture.child('Sentry Initialization');

      expect(
        sentryInit.attributes['sentry.op']?.value,
        'app.start.sentry_init',
      );
      expect(sentryInit.startTimestamp, fixture.sentrySetup);
      expect(sentryInit.isEnded, isFalse);
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
        expect(build.parentSpan, fixture.root);
        expect(build.attributes['flutter.frame.deferred']?.value, isTrue);
        for (final name in ['Root Widget Attachment', 'Frame Build']) {
          final span = fixture.child(name);
          expect(span.attributes['thread.name']?.value, 'main');
          expect(
            span.attributes['thread.id']?.value,
            'main'.hashCode.toString(),
          );
        }
        final raster = fixture.child('Frame Rasterization');
        expect(raster.attributes.containsKey('thread.name'), isFalse);
        expect(raster.attributes.containsKey('thread.id'), isFalse);
        expect(
          fixture.child('Frame Rasterization').startTimestamp,
          fixture.appStartResult.intervals.single.startTimestamp,
        );
        expect(
          fixture.child('Frame Rasterization').endTimestamp,
          fixture.naturalEnd,
        );
        expect(
          fixture.children.map((span) => span.name),
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
        fixture.children.map((span) => span.name),
        isNot(contains('Frame Build')),
      );
      expect(fixture.child('Frame Rasterization').isEnded, isTrue);
      expect(fixture.root!.isEnded, isFalse);
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
        fixture.root!.end(endTimestamp: fixture.rootFinish);
        await pumpEventQueue(times: 10);
        expect(fixture.child('Sentry Initialization').endTimestamp, lateInit);
        expect(fixture.root!.endTimestamp, lateInit);
        expect(fixture.root!.attributes['app.vitals.start.value']?.value, 350);
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
      'returns null and ends the root when the sentry init span is ignored',
      () {
        fixture.options.ignoreSpans = [
          IgnoreSpanRule.nameEquals('Sentry Initialization'),
        ];

        final trace = fixture.getSut();

        expect(trace, isNull);
        expect(fixture.root?.isEnded, isTrue);
        expect(fixture.processor.addedSpans, isEmpty);
      },
    );

    test(
      'returns null and ends created spans when phase creation throws',
      () async {
        final throwingFixture = ThrowingPhaseCreationFixture();

        final trace = throwingFixture.getSut();
        await pumpEventQueue(times: 10);

        expect(trace, isNull);
        expect(throwingFixture.hub.root?.isEnded, isTrue);
        expect(throwingFixture.hub.sentryInitSpan?.isEnded, isTrue);
      },
    );

    // Aborting only ends the root, which relies on the root having been told
    // about its children. That notification is dispatched through the lifecycle
    // registry, so an already-registered listener sits ahead of the root in the
    // dispatch order — as FramesTrackingIntegration does in a real SDK.
    test(
      'ends created spans when phase creation throws behind a listener',
      () async {
        final throwingFixture = ThrowingPhaseCreationFixture(
          leadingListener: (_) {},
        );

        final trace = throwingFixture.getSut();
        await pumpEventQueue(times: 10);

        expect(trace, isNull);
        expect(throwingFixture.hub.root?.isEnded, isTrue);
        expect(throwingFixture.hub.sentryInitSpan?.isEnded, isTrue);
      },
    );

    test('deregisters its process-span callback after enriching', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;
      final registry = fixture.options.lifecycleRegistry;

      expect(registry.lifecycleCallbacks[OnProcessSpan], hasLength(1));

      fixture.completeStartup(sut);
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

    test('close measures the app start to the first frame', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;
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

      expect(root.attributes['app.vitals.start.value']?.value, 350.0);
    });

    test('close completes when extension finalization fails', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;
      expect(
        sut.tryExtend(
          fixture.processStart.add(const Duration(milliseconds: 400)),
        ),
        isTrue,
      );
      fixture.options.clock = () => throw StateError('clock failed');

      await sut.close();
      await pumpEventQueue(times: 10);

      expect(root.isEnded, isTrue);
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

  /// What `options.clock` reads, so a test can move time on after creation.
  late DateTime clock = processStart.add(Duration(milliseconds: 300));

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
    ..telemetryProcessor = processor
    ..clock = () => clock;
  late final hub = Hub(options);
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final timing = AppStartTiming(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    sentrySetupTimestamp: sentrySetup,
    phases: [
      AppStartPhase(
        kind: AppStartPhaseKind.preInit,
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

  /// Drives the whole startup in production order: init ends, then the first
  /// frame renders. `Sentry Initialization` stays open until init ends, so a
  /// test that only records the frame never lets the root report.
  void completeStartup(StreamingAppStartTrace sut) {
    sut.recordInitEnd(initEnd);
    sut.recordFirstFrame(appStartResult);
  }

  /// The span named [description], which must be unique.
  RecordingSentrySpanV2 child(String description) =>
      children.singleWhere((span) => span.name == description)
          as RecordingSentrySpanV2;

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

  StreamingAppStartTrace? getSut({String Function()? startScreenNameProvider}) {
    final trace = StreamingAppStartTrace.tryCreate(
      hub: hub,
      timing: timing,
      startScreenNameProvider: startScreenNameProvider ?? () => 'root /',
    );
    // Otherwise the root's idle and deadline timers outlive the test.
    addTearDown(() => trace?.close());
    return trace;
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
  late final sentrySetup = processStart.add(Duration(milliseconds: 200));
  late final timing = AppStartTiming(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    sentrySetupTimestamp: sentrySetup,
    phases: [
      AppStartPhase(
        kind: AppStartPhaseKind.preInit,
        description: 'Pre-Init Startup',
        startTimestamp: processStart,
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
  RecordingSentrySpanV2? sentryInitSpan;

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
    if (name == 'Pre-Init Startup') {
      throw StateError('failed to start $name');
    }

    final span = _delegate.startInactiveSpan(
      name,
      attributes: attributes,
      parentSpan: parentSpan,
      startTimestamp: startTimestamp,
    );
    if (span is RecordingSentrySpanV2 && name == 'Sentry Initialization') {
      sentryInitSpan = span;
    }
    return span;
  }
}
