@TestOn('vm')
library dart_test;

import 'package:sentry/sentry.dart';
import 'package:sentry/src/load_dart_image_integration.dart';
import 'package:test/test.dart';

void main() {
  group(LoadDartImageIntegration(), () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
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

    test('Event processor does not modify event if symbolication is not needed',
        () async {
      final event = _getEvent(needsSymbolication: false);
      final processor = fixture.options.eventProcessors.first;
      final resultEvent = await processor.apply(event, Hint());

      expect(resultEvent, equals(event));
    });

    test('Event processor does not modify event if stackTrace is null',
        () async {
      final event = _getEvent();
      final processor = fixture.options.eventProcessors.first;
      final resultEvent = await processor.apply(event, Hint());

      expect(resultEvent, equals(event));
    });

    test('Event processor adds debug image when symbolication is needed',
        () async {
      final stackTrace = StackTrace.fromString('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
''');
      SentryEvent event = _getEvent();
      event = event.copyWith(stackTrace: stackTrace);

      final processor = fixture.options.eventProcessors.first;
      final resultEvent = await processor.apply(event, Hint());

      expect(resultEvent?.debugMeta?.images.length, 1);
      final debugImage = resultEvent?.debugMeta?.images.first;
      expect(debugImage?.debugId, isNotEmpty);
      expect(debugImage?.imageAddr, equals('0x10000000'));
    });

    test('Event processor adds debug image to existing debugMeta', () async {
      final stackTrace = StackTrace.fromString('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
''');
      final existingDebugImage = DebugImage(
        type: 'macho',
        debugId: 'existing-debug-id',
        imageAddr: '0x2000',
      );
      SentryEvent event = _getEvent();
      event = event.copyWith(
        stackTrace: stackTrace,
        debugMeta: DebugMeta(images: [existingDebugImage]),
      );

      final processor = fixture.options.eventProcessors.first;
      final resultEvent = await processor.apply(event, Hint());

      expect(resultEvent?.debugMeta?.images.length, 2);
      expect(resultEvent?.debugMeta?.images, contains(existingDebugImage));
      expect(
          resultEvent?.debugMeta?.images.last.imageAddr, equals('0x10000000'));
    });
  });
}

class Fixture {
  final options = SentryOptions(dsn: 'https://public@sentry.example.com/1');

  Fixture() {
    final integration = LoadDartImageIntegration();
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
