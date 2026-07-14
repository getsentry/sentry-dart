// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_data.dart';
import 'package:sentry_flutter/src/app_start/streaming_app_start_trace.dart';

import '../mocks.dart';

void main() {
  group('$StreamingAppStartTrace', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('encodes the standalone root after natural end', () async {
      final sut = fixture.getSut()!;
      final root = fixture.root!;

      sut.recordNaturalEnd(fixture.naturalEnd);
      root.end(endTimestamp: fixture.rootFinish);
      await pumpEventQueue(times: 10);

      expect(root.name, 'App Start');
      expect(
        root.attributes['sentry.op']?.value,
        'app.start',
      );
      expect(
        root.attributes['sentry.origin']?.value,
        'auto.app.start',
      );
      expect(root.attributes['app.vitals.start.value']?.value, 350.0);
      expect(root.attributes['app.vitals.start.cold.value']?.value, 350.0);
      expect(root.attributes['app.vitals.start.type']?.value, 'cold');
      expect(root.attributes['app.vitals.start.screen']?.value, 'root /');
      expect(root.attributes['sentry.segment.name']?.value, 'App Start');
      expect(fixture.completions, 1);
    });

    test('creates direct standalone breakdown children', () {
      fixture.getSut();

      expect(fixture.children, hasLength(3));
      expect(
        fixture.children.map((span) => span.parentSpan),
        everyElement(same(fixture.root)),
      );
    });

    test('omits duration and retains metadata at deadline', () async {
      fixture.getSut();
      final root = fixture.root!;

      root.status = SentrySpanStatusV2.error;
      root.setAttribute(
        'sentry.status.message',
        SentryAttribute.string('deadline_exceeded'),
      );
      root.end(
        endTimestamp: fixture.processStart.add(Duration(seconds: 30)),
      );
      await pumpEventQueue(times: 10);

      expect(root.attributes['app.vitals.start.value'], isNull);
      expect(root.attributes['app.vitals.start.type']?.value, 'cold');
      expect(root.attributes['app.vitals.start.screen']?.value, 'root /');
    });

    test('uses extension end instead of a later descendant', () async {
      final sut = fixture.getSut()!;
      expect(sut.tryCreateExtension(fixture.extensionStart), isTrue);
      final extension = sut.activeStreamingExtension! as RecordingSentrySpanV2;
      final descendant = fixture.hub.startInactiveSpan(
        'initialization',
        parentSpan: extension,
        startTimestamp: fixture.extensionStart,
      );

      extension.end(endTimestamp: fixture.extensionEnd);
      descendant.end(endTimestamp: fixture.descendantEnd);
      sut.recordNaturalEnd(fixture.naturalEnd);
      final root = fixture.root!;
      root.end(endTimestamp: fixture.rootFinish);
      await pumpEventQueue(times: 10);

      expect(root.attributes['app.vitals.start.value']?.value, 400.0);
      expect(root.endTimestamp, fixture.descendantEnd);
      expect(sut.activeStreamingExtension, isNull);
    });

    test('does not extend after natural end', () {
      final sut = fixture.getSut()!;

      sut.recordNaturalEnd(fixture.naturalEnd);

      expect(sut.tryCreateExtension(fixture.extensionStart), isFalse);
    });
  });
}

class Fixture {
  final processStart = DateTime.utc(2024, 1, 1, 12);
  late final naturalEnd = processStart.add(Duration(milliseconds: 350));
  late final extensionStart = processStart.add(Duration(milliseconds: 300));
  late final extensionEnd = processStart.add(Duration(milliseconds: 400));
  late final descendantEnd = processStart.add(Duration(milliseconds: 450));
  late final rootFinish = processStart.add(Duration(milliseconds: 500));
  var completions = 0;
  IdleRecordingSentrySpanV2? root;
  final children = <SentrySpanV2>[];

  late final options = defaultTestOptions()
    ..tracesSampleRate = 1.0
    ..traceLifecycle = SentryTraceLifecycle.stream
    ..clock = () => processStart.add(Duration(milliseconds: 300));
  late final hub = Hub(options);
  late final data = AppStartData(
    type: AppStartType.cold,
    processStartTimestamp: processStart,
    pluginRegistrationTimestamp: processStart.add(Duration(milliseconds: 100)),
    sentrySetupTimestamp: processStart.add(Duration(milliseconds: 200)),
    nativePhaseIntervals: [],
  );

  StreamingAppStartTrace? getSut() {
    options.lifecycleRegistry.registerCallback<OnSpanStartV2>((event) {
      final span = event.span;
      if (span is IdleRecordingSentrySpanV2) {
        root ??= span;
      } else if (span.parentSpan != null) {
        children.add(span);
      }
    });
    return StreamingAppStartTrace.tryCreate(
      hub: hub,
      data: data,
      onCompleted: () => completions++,
      initialScreenName: () => 'root /',
    );
  }
}
