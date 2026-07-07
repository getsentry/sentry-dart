// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_info.dart';
import 'package:sentry_flutter/src/app_start/stream_app_start_span_writer.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$StreamAppStartSpanWriter', () {
    test('writes attached app-start shape under ui.load root', () {
      final root = fixture.startRoot('root /');

      fixture.sut.writeAttached(root, fixture.appStartInfo);

      final appStartSpan = fixture.findSpan('Cold Start')!;
      expect(appStartSpan.parentSpan, same(root));
      expect(
        appStartSpan.attributes[SemanticAttributesConstants.sentryOp]?.value,
        'app.start.cold',
      );
      expect(
        appStartSpan.attributes[SemanticAttributesConstants.sentryOrigin],
        isNull,
      );
      expect(
        fixture
            .findSpan(AppStartInfo.pluginRegistrationDescription)
            ?.parentSpan,
        same(appStartSpan),
      );
      expect(
        appStartSpan
            .attributes[SemanticAttributesConstants.appVitalsStartValue]?.value,
        50.0,
      );
    });

    test('writes standalone breakdown spans directly under root', () {
      final root = fixture.startRoot('App Start');

      fixture.sut.writeStandalone(root, fixture.appStartInfo);
      fixture.sut.finish(root, fixture.appStartInfo);

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
      expect(
        fixture
            .findSpan('native span')
            ?.attributes[SemanticAttributesConstants.sentryOrigin]
            ?.value,
        SentryTraceOrigins.autoAppStart,
      );
      expect(
        root.attributes[SemanticAttributesConstants.appVitalsStartValue]?.value,
        50.0,
      );
      expect(root.endTimestamp, fixture.appStartInfo.end.toUtc());
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream;
  late final hub = Hub(options);
  late final sut = StreamAppStartSpanWriter(hub: hub);
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

  RecordingSentrySpanV2 startRoot(String name) {
    return hub.startIdleSpan(
      name,
      startTimestamp: appStartInfo.start,
    ) as RecordingSentrySpanV2;
  }

  RecordingSentrySpanV2? findSpan(String name) {
    return capturedSpans.firstWhereOrNull((span) => span.name == name);
  }
}
