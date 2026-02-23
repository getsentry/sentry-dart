// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group(TimeToDisplayTrackerV2, () {
    group('when tracking a route', () {
      test('cancels previous tracked route span', () {
        final sut = fixture.getSut();

        sut.trackRoute('/previous-route');
        final activeSpan = fixture.hub.getActiveSpan();
        expect(activeSpan, isNotNull);
        expect(activeSpan!.isEnded, isFalse);

        sut.trackRoute('/new-route');

        expect(activeSpan.isEnded, isTrue);
        expect(activeSpan.status, SentrySpanStatusV2.cancelled);
      });

      test('starts idle root span with ui.load op', () {
        final sut = fixture.getSut();

        sut.trackRoute('/test-route');

        final activeSpan = fixture.hub.getActiveSpan();
        expect(activeSpan, isNotNull);
        expect(activeSpan!.name, '/test-route');
        expect(
          activeSpan.attributes[SemanticAttributesConstants.sentryOp]?.value,
          SentrySpanOperations.uiLoad,
        );
        expect(
          activeSpan
              .attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          SentryTraceOrigins.autoNavigationRouteObserver,
        );
      });

      test('ends TTID span on next frame callback', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/test-route');

        final ttidSpan = childSpans.firstWhere(
          (s) => s.name == '/test-route initial display',
        );

        expect(ttidSpan.isEnded, isFalse);

        fixture.frameCallbackHandler.postFrameCallback?.call(Duration.zero);

        expect(ttidSpan.isEnded, isTrue);
      });

      test('stores TTFD span id', () {
        final sut = fixture.getSut();

        expect(sut.ttfdSpanId, isNull);

        sut.trackRoute('/test-route');

        expect(sut.ttfdSpanId, isNotNull);
      });

      test('creates TTID span with correct op and origin', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/settings');

        final ttidSpan = childSpans.firstWhere(
          (s) => s.name == '/settings initial display',
        );

        expect(
          ttidSpan.attributes[SemanticAttributesConstants.sentryOp]?.value,
          SentrySpanOperations.uiTimeToInitialDisplay,
        );
        expect(
          ttidSpan.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          SentryTraceOrigins.autoNavigationRouteObserver,
        );
      });

      test('creates TTFD span when enableTimeToFullDisplayTracing is true',
          () {
        fixture.options.enableTimeToFullDisplayTracing = true;
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/test-route');

        final ttfdSpans = childSpans.where(
          (s) => s.name == '/test-route full display',
        );
        expect(ttfdSpans, hasLength(1));
        expect(sut.ttfdSpanId, isNotNull);
      });

      test(
          'does not create TTFD span when enableTimeToFullDisplayTracing is false',
          () {
        fixture.options.enableTimeToFullDisplayTracing = false;
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/test-route');

        final ttfdSpans = childSpans.where(
          (s) => s.name == '/test-route full display',
        );
        expect(ttfdSpans, isEmpty);
        expect(sut.ttfdSpanId, isNull);
      });

      test('creates TTFD span with correct op and origin', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/settings');

        final ttfdSpan = childSpans.firstWhere(
          (s) => s.name == '/settings full display',
        );

        expect(
          ttfdSpan.attributes[SemanticAttributesConstants.sentryOp]?.value,
          SentrySpanOperations.uiTimeToFullDisplay,
        );
        expect(
          ttfdSpan.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          SentryTraceOrigins.autoNavigationRouteObserver,
        );
      });
    });

    group('when reporting fully displayed', () {
      test('ends TTFD span with matching spanId', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/test-route');
        final ttfdSpanId = sut.ttfdSpanId!;

        final ttfdSpan = childSpans.firstWhere(
          (s) => s.name == '/test-route full display',
        );
        expect(ttfdSpan.isEnded, isFalse);

        sut.reportFullyDisplayed(ttfdSpanId);

        expect(ttfdSpan.isEnded, isTrue);
        expect(sut.ttfdSpanId, isNull);
      });

      test('ignores mismatched spanId', () {
        final sut = fixture.getSut();

        sut.trackRoute('/test-route');
        final originalTtfdSpanId = sut.ttfdSpanId;

        sut.reportFullyDisplayed(SpanId.newId());

        expect(sut.ttfdSpanId, originalTtfdSpanId);
      });
    });

    group('when cancelling current route', () {
      test('ends TTFD span with cancelled status', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.trackRoute('/test-route');

        final ttfdSpan = childSpans.firstWhere(
          (s) => s.name == '/test-route full display',
        );
        expect(ttfdSpan.isEnded, isFalse);

        sut.cancelCurrentRoute();

        expect(ttfdSpan.isEnded, isTrue);
        expect(ttfdSpan.status, SentrySpanStatusV2.cancelled);
        expect(sut.ttfdSpanId, isNull);
      });

      test('ends active idle route span with cancelled status', () {
        final sut = fixture.getSut();

        sut.trackRoute('/test-route');

        final activeSpan = fixture.hub.getActiveSpan();
        expect(activeSpan, isNotNull);
        expect(activeSpan!.isEnded, isFalse);

        sut.cancelCurrentRoute();

        expect(activeSpan.isEnded, isTrue);
        expect(activeSpan.status, SentrySpanStatusV2.cancelled);
      });

      test('cancels an existing idle span not created by trackRoute', () {
        final sut = fixture.getSut();

        // Create an idle span externally (e.g. simulating a user interaction span)
        final externalIdleSpan =
            fixture.hub.startIdleSpan('user interaction span');
        expect(externalIdleSpan.isEnded, isFalse);

        sut.cancelCurrentRoute();

        expect(externalIdleSpan.isEnded, isTrue);
        expect(externalIdleSpan.status, SentrySpanStatusV2.cancelled);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.streaming
    ..enableTimeToFullDisplayTracing = true;

  late final hub = Hub(options);
  final frameCallbackHandler = FakeFrameCallbackHandler();

  TimeToDisplayTrackerV2 getSut() {
    return TimeToDisplayTrackerV2(
      hub: hub,
      frameCallbackHandler: frameCallbackHandler,
    );
  }

  List<RecordingSentrySpanV2> captureChildSpans() {
    final capturedSpans = <RecordingSentrySpanV2>[];
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span case final RecordingSentrySpanV2 span
          when span.parentSpan != null) {
        capturedSpans.add(span);
      }
    });
    return capturedSpans;
  }
}
