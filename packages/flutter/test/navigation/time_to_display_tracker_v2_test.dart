// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

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
    group('when tracking route changes', () {
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

      test('starts idle root span with ui.load op and correct origin', () {
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

      test('creates TTFD span when enableTimeToFullDisplayTracing is true', () {
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

      test('returns the created route span', () {
        final sut = fixture.getSut();

        final routeSpan = sut.trackRoute('/test-route');

        expect(routeSpan, isA<RecordingSentrySpanV2>());
        expect(routeSpan.name, '/test-route');
      });
    });

    group('when tracking app start', () {
      test('returns idle span named root /', () {
        final sut = fixture.getSut();

        final routeSpan = sut.trackAppStart();

        expect(routeSpan, isA<RecordingSentrySpanV2>());
        expect(routeSpan.name, 'root /');
        expect(fixture.hub.getActiveSpan()?.spanId, routeSpan.spanId);
      });

      group('with startTimestamp', () {
        test('backdates idle root span start time', () {
          final sut = fixture.getSut();
          final past = DateTime.utc(2024, 1, 1, 12, 0, 0);

          sut.trackAppStart(startTimestamp: past);

          final activeSpan =
              fixture.hub.getActiveSpan() as RecordingSentrySpanV2;
          expect(activeSpan.startTimestamp, equals(past));
        });

        test('backdates TTID and TTFD child spans', () {
          final sut = fixture.getSut();
          final childSpans = fixture.captureChildSpans();
          final past = DateTime.utc(2024, 1, 1, 12, 0, 0);

          sut.trackAppStart(startTimestamp: past);

          final ttidSpan = childSpans.firstWhere(
            (s) => s.name == 'root / initial display',
          );
          final ttfdSpan = childSpans.firstWhere(
            (s) => s.name == 'root / full display',
          );

          expect(ttidSpan.startTimestamp, equals(past));
          expect(ttfdSpan.startTimestamp, equals(past));
        });
      });

      group('with ttidEndTimestamp', () {
        test('ends TTID span immediately with provided timestamp', () {
          final sut = fixture.getSut();
          final childSpans = fixture.captureChildSpans();
          final ttidEnd = DateTime.utc(2024, 1, 1, 12, 0, 5);

          sut.trackAppStart(ttidEndTimestamp: ttidEnd);

          final ttidSpan = childSpans.firstWhere(
            (s) => s.name == 'root / initial display',
          );

          expect(ttidSpan.isEnded, isTrue);
          expect(ttidSpan.endTimestamp, equals(ttidEnd));
        });

        test('does not register frame callback', () {
          final sut = fixture.getSut();

          sut.trackAppStart(ttidEndTimestamp: DateTime.now());

          expect(fixture.frameCallbackHandler.postFrameCallback, isNull);
        });

        test('keeps TTFD span open', () {
          final sut = fixture.getSut();
          final childSpans = fixture.captureChildSpans();

          sut.trackAppStart(ttidEndTimestamp: DateTime.now());

          final ttfdSpan = childSpans.firstWhere(
            (s) => s.name == 'root / full display',
          );
          expect(ttfdSpan.isEnded, isFalse);
        });
      });
    });

    group('when preparing app start', () {
      test('creates idle span eagerly', () {
        final sut = fixture.getSut();

        sut.prepareAppStart();

        final activeSpan = fixture.hub.getActiveSpan();
        expect(activeSpan, isNotNull);
        expect(activeSpan!.name, 'root /');
      });

      test('makes ttfdSpanId available immediately', () {
        final sut = fixture.getSut();

        expect(sut.ttfdSpanId, isNull);

        sut.prepareAppStart();

        expect(sut.ttfdSpanId, isNotNull);
      });

      test('does not create TTFD span when disabled', () {
        fixture.options.enableTimeToFullDisplayTracing = false;
        final sut = fixture.getSut();

        sut.prepareAppStart();

        expect(sut.ttfdSpanId, isNull);
      });

      test('cancels existing route before preparing', () {
        final sut = fixture.getSut();

        sut.trackRoute('/existing-route');
        final existingSpan = fixture.hub.getActiveSpan();
        expect(existingSpan!.isEnded, isFalse);

        sut.prepareAppStart();

        expect(existingSpan.isEnded, isTrue);
        expect(existingSpan.status, SentrySpanStatusV2.cancelled);
      });
    });

    group('when tracking app start after prepare', () {
      test('reuses prepared idle span', () {
        final sut = fixture.getSut();

        sut.prepareAppStart();
        final preparedSpan = fixture.hub.getActiveSpan();

        final routeSpan = sut.trackAppStart();

        expect(routeSpan.spanId, equals(preparedSpan!.spanId));
      });

      test('backdates prepared span start timestamp', () {
        final sut = fixture.getSut();
        final past = DateTime.utc(2024, 1, 1, 12, 0, 0);

        sut.prepareAppStart();
        sut.trackAppStart(startTimestamp: past);

        final activeSpan = fixture.hub.getActiveSpan() as RecordingSentrySpanV2;
        expect(activeSpan.startTimestamp, equals(past));
      });

      test('backdates pre-created TTFD span start timestamp', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();
        final past = DateTime.utc(2024, 1, 1, 12, 0, 0);

        sut.prepareAppStart();
        sut.trackAppStart(startTimestamp: past);

        final ttfdSpan = childSpans.firstWhere(
          (s) => s.name == 'root / full display',
        );
        expect(ttfdSpan.startTimestamp, equals(past));
      });

      test('creates TTID span as child of prepared route span', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.prepareAppStart();
        sut.trackAppStart();

        final ttidSpan = childSpans.firstWhere(
          (s) => s.name == 'root / initial display',
        );
        expect(ttidSpan, isNotNull);
        expect(ttidSpan.isEnded, isFalse);

        fixture.frameCallbackHandler.postFrameCallback?.call(Duration.zero);

        expect(ttidSpan.isEnded, isTrue);
      });

      test('does not create duplicate TTFD span', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();

        sut.prepareAppStart();
        sut.trackAppStart();

        final ttfdSpans = childSpans.where(
          (s) => s.name == 'root / full display',
        );
        expect(ttfdSpans, hasLength(1));
      });

      test('ends TTID immediately with ttidEndTimestamp', () {
        final sut = fixture.getSut();
        final childSpans = fixture.captureChildSpans();
        final ttidEnd = DateTime.utc(2024, 1, 1, 12, 0, 5);

        sut.prepareAppStart();
        sut.trackAppStart(ttidEndTimestamp: ttidEnd);

        final ttidSpan = childSpans.firstWhere(
          (s) => s.name == 'root / initial display',
        );
        expect(ttidSpan.isEnded, isTrue);
        expect(ttidSpan.endTimestamp, equals(ttidEnd));
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
      test('clears TTFD span id', () {
        final sut = fixture.getSut();

        sut.trackRoute('/test-route');
        expect(sut.ttfdSpanId, isNotNull);

        sut.cancelCurrentRoute();

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

      test('cancels an existing idle span not created by the tracker', () {
        final sut = fixture.getSut();

        final externalIdleSpan =
            fixture.hub.startIdleSpan('user interaction span');
        expect(externalIdleSpan.isEnded, isFalse);

        sut.cancelCurrentRoute();

        expect(externalIdleSpan.isEnded, isTrue);
        expect(externalIdleSpan.status, SentrySpanStatusV2.cancelled);
      });

      test('clears prepared app start span', () {
        final sut = fixture.getSut();

        sut.prepareAppStart();
        final preparedSpan = fixture.hub.getActiveSpan();
        expect(preparedSpan!.isEnded, isFalse);

        sut.cancelCurrentRoute();

        expect(preparedSpan.isEnded, isTrue);
        expect(preparedSpan.status, SentrySpanStatusV2.cancelled);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
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
