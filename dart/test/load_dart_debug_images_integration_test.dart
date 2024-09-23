@TestOn('vm')
library dart_test;

import 'package:sentry/sentry.dart';
import 'package:sentry/src/load_dart_debug_images_integration.dart';
import 'package:test/test.dart';

import 'mocks/mock_platform.dart';
import 'mocks/mock_platform_checker.dart';
import 'test_utils.dart';

void main() {
  group(LoadDartDebugImagesIntegration, () {
    late Fixture fixture;

    final platforms = [
      MockPlatform.iOS(),
      MockPlatform.macOS(),
      MockPlatform.android(),
    ];

    for (final platform in platforms) {
      setUp(() {
        fixture = Fixture();
        fixture.options.platformChecker =
            MockPlatformChecker(platform: platform);
      });

      test('adds itself to sdk.integrations', () {
        expect(
          fixture.options.sdk.integrations.contains('loadDartImageIntegration'),
          true,
        );
      });

      test('Event processor is added to options', () {
        expect(fixture.options.eventProcessors.length, 1);
        expect(
          fixture.options.eventProcessors.first.runtimeType.toString(),
          '_LoadImageIntegrationEventProcessor',
        );
      });

      test(
          'Event processor does not add debug image if symbolication is not needed',
          () async {
        final event = _getEvent(needsSymbolication: false);
        final processor = fixture.options.eventProcessors.first;
        final resultEvent = await processor.apply(event, Hint());

        expect(resultEvent, equals(event));
      });

      test('Event processor does not add debug image if stackTrace is null',
          () async {
        final event = _getEvent();
        final processor = fixture.options.eventProcessors.first;
        final resultEvent = await processor.apply(event, Hint());

        expect(resultEvent, equals(event));
      });

      test(
          'Event processor does not add debug image if enableDartSymbolication is false',
          () async {
        fixture.options.enableDartSymbolication = false;
        final event = _getEvent();
        final processor = fixture.options.eventProcessors.first;
        final resultEvent = await processor.apply(event, Hint());

        expect(resultEvent, equals(event));
      });

      test('Event processor adds debug image when symbolication is needed',
          () async {
        final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
''';
        SentryEvent event = _getEvent();
        final processor = fixture.options.eventProcessors.first;
        final resultEvent = await processor.apply(
            event, Hint()..set(hintRawStackTraceKey, stackTrace));

        expect(resultEvent?.debugMeta?.images.length, 1);
        final debugImage = resultEvent?.debugMeta?.images.first;
        expect(debugImage?.debugId, isNotEmpty);
        expect(debugImage?.imageAddr, equals('0x10000000'));
      });
    }
  });
}

class Fixture {
  final options = defaultTestOptions();

  Fixture() {
    final integration = LoadDartDebugImagesIntegration();
    integration.call(Hub(options), options);
  }
}

SentryEvent _getEvent({bool needsSymbolication = true}) {
  final frame =
      SentryStackFrame(platform: needsSymbolication ? 'native' : 'dart');
  final st = SentryStackTrace(frames: [frame]);
  return SentryEvent(
      threads: [SentryThread(stacktrace: st)], debugMeta: DebugMeta());
}
