// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/native_app_start_handler_v2.dart';
import 'package:sentry_flutter/src/native/native_app_start.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker_v2.dart';

import '../fake_frame_callback_handler.dart';
import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group(NativeAppStartHandlerV2, () {
    test('creates root idle span via tracker with backdated start', () async {
      await fixture.call();

      final rootSpan = fixture.hub.getActiveSpan();
      expect(rootSpan, isNotNull);
      expect(rootSpan!.name, 'root /');
      expect(rootSpan.startTimestamp, fixture.appStartDateTime.toUtc());
      expect(
        rootSpan.attributes[SemanticAttributesConstants.sentryOp]?.value,
        SentrySpanOperations.uiLoad,
      );
    });

    test('creates app start span as child of root span', () async {
      await fixture.call();

      final appStartSpan = fixture.findSpanByName('Cold Start');
      expect(appStartSpan, isNotNull);
      expect(appStartSpan!.startTimestamp, fixture.appStartDateTime.toUtc());
      expect(appStartSpan.isEnded, isTrue);
      expect(appStartSpan.endTimestamp, fixture.appStartEnd.toUtc());
      expect(
        appStartSpan.attributes[SemanticAttributesConstants.sentryOp]?.value,
        'app.start.cold',
      );
    });

    test('creates plugin registration phase span', () async {
      await fixture.call();

      final span = fixture.findSpanByName('App start to plugin registration');
      expect(span, isNotNull);
      expect(span!.startTimestamp, fixture.appStartDateTime.toUtc());
      expect(span.endTimestamp, fixture.pluginRegistrationDateTime.toUtc());
      expect(span.isEnded, isTrue);
    });

    test('creates sentry setup phase span', () async {
      await fixture.call();

      final span = fixture.findSpanByName('Before Sentry Init Setup');
      expect(span, isNotNull);
      expect(span!.startTimestamp, fixture.pluginRegistrationDateTime.toUtc());
      expect(span.endTimestamp, fixture.sentrySetupStartDateTime.toUtc());
      expect(span.isEnded, isTrue);
    });

    test('creates first frame render phase span', () async {
      await fixture.call();

      final span = fixture.findSpanByName('First frame render');
      expect(span, isNotNull);
      expect(span!.startTimestamp, fixture.sentrySetupStartDateTime.toUtc());
      expect(span.endTimestamp, fixture.appStartEnd.toUtc());
      expect(span.isEnded, isTrue);
    });

    test('all phase spans have correct op', () async {
      await fixture.call();

      final phaseNames = [
        'App start to plugin registration',
        'Before Sentry Init Setup',
        'First frame render',
      ];

      for (final name in phaseNames) {
        final span = fixture.findSpanByName(name);
        expect(span, isNotNull, reason: 'Expected span: $name');
        expect(
          span!.attributes[SemanticAttributesConstants.sentryOp]?.value,
          'app.start.cold',
          reason: 'Wrong op for span: $name',
        );
      }
    });

    test('all phase spans are children of app start span', () async {
      await fixture.call();

      final appStartSpan = fixture.findSpanByName('Cold Start');
      expect(appStartSpan, isNotNull);

      final phaseNames = [
        'App start to plugin registration',
        'Before Sentry Init Setup',
        'First frame render',
      ];

      for (final name in phaseNames) {
        final span = fixture.findSpanByName(name);
        expect(span, isNotNull, reason: 'Expected span: $name');
        expect(
          span!.parentSpan?.spanId,
          appStartSpan!.spanId,
          reason: 'Span $name should be child of Cold Start',
        );
      }
    });

    test('creates native child spans under app start span', () async {
      await fixture.call();

      final appStartSpan = fixture.findSpanByName('Cold Start');
      expect(appStartSpan, isNotNull);

      final nativeSpan1 = fixture.findSpanByName('native span 1');
      final nativeSpan2 = fixture.findSpanByName('native span 2');

      expect(nativeSpan1, isNotNull);
      expect(nativeSpan2, isNotNull);
      expect(nativeSpan1!.parentSpan?.spanId, appStartSpan!.spanId);
      expect(nativeSpan2!.parentSpan?.spanId, appStartSpan.spanId);

      expect(nativeSpan1.startTimestamp,
          DateTime.fromMillisecondsSinceEpoch(1).toUtc());
      expect(nativeSpan1.endTimestamp,
          DateTime.fromMillisecondsSinceEpoch(2).toUtc());
      expect(nativeSpan1.isEnded, isTrue);

      expect(nativeSpan2.startTimestamp,
          DateTime.fromMillisecondsSinceEpoch(3).toUtc());
      expect(nativeSpan2.endTimestamp,
          DateTime.fromMillisecondsSinceEpoch(4).toUtc());
      expect(nativeSpan2.isEnded, isTrue);
    });

    test('does not end root idle span (it auto-ends via timeout)', () async {
      await fixture.call();

      final rootSpan = fixture.hub.getActiveSpan();
      expect(rootSpan, isNotNull);
      expect(rootSpan!.isEnded, isFalse);
    });

    test('TTID span is ended with app start end timestamp', () async {
      await fixture.call();

      final ttidSpan = fixture.findSpanByName('root / initial display');
      expect(ttidSpan, isNotNull);
      expect(ttidSpan!.isEnded, isTrue);
      expect(ttidSpan.endTimestamp, fixture.appStartEnd.toUtc());
    });

    test('TTFD span remains open', () async {
      await fixture.call();

      final ttfdSpan = fixture.findSpanByName('root / full display');
      expect(ttfdSpan, isNotNull);
      expect(ttfdSpan!.isEnded, isFalse);
    });

    test('returns early when native app start is null', () async {
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenAnswer((_) async => null);

      await fixture.call();

      expect(fixture.hub.getActiveSpan(), isNull);
      expect(fixture.capturedSpans, isEmpty);
    });

    test('returns early when app start duration exceeds 60s', () async {
      await fixture.call(
        appStartEnd: DateTime.fromMillisecondsSinceEpoch(60001),
      );

      expect(fixture.hub.getActiveSpan(), isNull);
      expect(fixture.capturedSpans, isEmpty);
    });

    test('warm start uses correct op and description', () async {
      when(fixture.nativeBinding.fetchNativeAppStart())
          .thenAnswer((_) async => fixture.warmNativeAppStart);

      await fixture.call();

      final appStartSpan = fixture.findSpanByName('Warm Start');
      expect(appStartSpan, isNotNull);
      expect(
        appStartSpan!.attributes[SemanticAttributesConstants.sentryOp]?.value,
        'app.start.warm',
      );
    });

    group('when emitting app start vitals', () {
      test('cold start emits legacy cold value and unified value and type',
          () async {
        await fixture.call();

        final appStartSpan = fixture.findSpanByName('Cold Start')!;
        final expectedDurationMs = fixture.appStartEnd
            .difference(fixture.appStartDateTime)
            .inMilliseconds
            .toDouble();

        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartColdValue]
              ?.value,
          expectedDurationMs,
        );
        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartValue]
              ?.value,
          expectedDurationMs,
        );
        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartType]
              ?.value,
          'cold',
        );
        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartWarmValue],
          isNull,
        );
      });

      test('warm start emits legacy warm value and unified value and type',
          () async {
        when(fixture.nativeBinding.fetchNativeAppStart())
            .thenAnswer((_) async => fixture.warmNativeAppStart);

        await fixture.call();

        final appStartSpan = fixture.findSpanByName('Warm Start')!;
        final expectedDurationMs = fixture.appStartEnd
            .difference(fixture.appStartDateTime)
            .inMilliseconds
            .toDouble();

        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartWarmValue]
              ?.value,
          expectedDurationMs,
        );
        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartValue]
              ?.value,
          expectedDurationMs,
        );
        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartType]
              ?.value,
          'warm',
        );
        expect(
          appStartSpan
              .attributes[SemanticAttributesConstants.appVitalsStartColdValue],
          isNull,
        );
      });
    });

    test('all spans have correct origin', () async {
      await fixture.call();

      final spanNames = [
        'Cold Start',
        'App start to plugin registration',
        'Before Sentry Init Setup',
        'First frame render',
        'native span 1',
        'native span 2',
      ];

      for (final name in spanNames) {
        final span = fixture.findSpanByName(name);
        expect(span, isNotNull, reason: 'Expected span: $name');
        expect(
          span!.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
          SentryTraceOrigins.autoUiTimeToDisplay,
          reason: 'Wrong origin for span: $name',
        );
      }
    });

    test('all app start spans have app start type', () async {
      await fixture.call();

      final appStartSpanNames = [
        'Cold Start',
        'App start to plugin registration',
        'Before Sentry Init Setup',
        'First frame render',
        'native span 1',
        'native span 2',
      ];

      for (final name in appStartSpanNames) {
        final span = fixture.findSpanByName(name);
        expect(span, isNotNull, reason: 'Expected span: $name');
        expect(
          span!.attributes[SemanticAttributesConstants.appVitalsStartType]
              ?.value,
          'cold',
          reason: 'Wrong app start type for span: $name',
        );
      }
    });
  });
}

class Fixture {
  final appStartDateTime = DateTime.fromMillisecondsSinceEpoch(0);
  final pluginRegistrationDateTime = DateTime.fromMillisecondsSinceEpoch(10);
  final sentrySetupStartDateTime = DateTime.fromMillisecondsSinceEpoch(15);
  final appStartEnd = DateTime.fromMillisecondsSinceEpoch(50);

  final nativeBinding = MockSentryNativeBinding();
  final frameCallbackHandler = FakeFrameCallbackHandler();

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
    ..enableTimeToFullDisplayTracing = true;

  late final hub = Hub(options);

  final capturedSpans = <RecordingSentrySpanV2>[];

  final nativeAppStart = NativeAppStart(
    appStartTime: 0,
    pluginRegistrationTime: 10,
    isColdStart: true,
    nativeSpanTimes: {
      'native span 1': {
        'startTimestampMsSinceEpoch': 1,
        'stopTimestampMsSinceEpoch': 2,
      },
      'native span 2': {
        'startTimestampMsSinceEpoch': 3,
        'stopTimestampMsSinceEpoch': 4,
      },
    },
  );

  final warmNativeAppStart = NativeAppStart(
    appStartTime: 0,
    pluginRegistrationTime: 10,
    isColdStart: false,
    nativeSpanTimes: {},
  );

  late final sut = NativeAppStartHandlerV2(nativeBinding);

  Fixture() {
    SentryFlutter.sentrySetupStartTime = sentrySetupStartDateTime;

    when(nativeBinding.fetchNativeAppStart())
        .thenAnswer((_) async => nativeAppStart);

    options.timeToDisplayTrackerV2 = TimeToDisplayTrackerV2(
      hub: hub,
      frameCallbackHandler: frameCallbackHandler,
    );

    // Capture all child spans via lifecycle registry
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span case final RecordingSentrySpanV2 span
          when span.parentSpan != null) {
        capturedSpans.add(span);
      }
    });
  }

  Future<void> call({DateTime? appStartEnd}) async {
    await sut.call(
      hub,
      options,
      appStartEnd: appStartEnd ?? this.appStartEnd,
    );
  }

  RecordingSentrySpanV2? findSpanByName(String name) {
    return capturedSpans.firstWhereOrNull((s) => s.name == name);
  }
}
