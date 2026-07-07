// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_info.dart';
import 'package:sentry_flutter/src/app_start/stream_standalone_app_start_emitter.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$StreamStandaloneAppStartEmitter', () {
    test('creates detached App Start root with app.start op', () async {
      await fixture.sut.emit(fixture.appStartInfo);

      final root = fixture.findSpan('App Start')!;
      expect(root.parentSpan, isNull);
      expect(
        root.attributes[SemanticAttributesConstants.sentryOp]?.value,
        SentrySpanOperations.appStart,
      );
      expect(
        root.attributes[SemanticAttributesConstants.sentryOrigin]?.value,
        SentryTraceOrigins.autoAppStart,
      );
      expect(root.endTimestamp, fixture.appStartInfo.end.toUtc());
      expect(
        root.attributes[SemanticAttributesConstants.appVitalsStartValue]?.value,
        50.0,
      );
    });

    test('attaches standalone breakdown spans directly under root', () async {
      await fixture.sut.emit(fixture.appStartInfo);

      final root = fixture.findSpan('App Start')!;
      expect(fixture.findSpan('Cold Start'), isNull);
      expect(
        fixture
            .findSpan(AppStartInfo.pluginRegistrationDescription)
            ?.parentSpan,
        same(root),
      );
      expect(fixture.findSpan('native span')?.parentSpan, same(root));
      expect(
        fixture
            .findSpan('native span')
            ?.attributes[SemanticAttributesConstants.sentryOp]
            ?.value,
        SentrySpanOperations.appStartNative,
      );
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream;
  late final hub = Hub(options);
  late final sut = StreamStandaloneAppStartEmitter(hub: hub);
  final capturedSpans = <RecordingSentrySpanV2>[];

  final appStartInfo = AppStartInfo(
    AppStartType.cold,
    start: DateTime.fromMillisecondsSinceEpoch(0),
    end: DateTime.fromMillisecondsSinceEpoch(50),
    pluginRegistration: DateTime.fromMillisecondsSinceEpoch(10),
    sentrySetupStart: DateTime.fromMillisecondsSinceEpoch(15),
    nativeSpanTimes: [
      TimeSpan(
        start: DateTime.fromMillisecondsSinceEpoch(1),
        end: DateTime.fromMillisecondsSinceEpoch(2),
        description: 'native span',
      ),
    ],
  );

  Fixture() {
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      if (event.span case final RecordingSentrySpanV2 span) {
        capturedSpans.add(span);
      }
    });
  }

  RecordingSentrySpanV2? findSpan(String name) {
    return capturedSpans.firstWhereOrNull((span) => span.name == name);
  }
}
