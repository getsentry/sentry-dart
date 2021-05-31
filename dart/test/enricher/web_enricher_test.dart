@TestOn('browser')
import 'package:sentry/sentry.dart';
import 'package:sentry/src/enricher/web_enricher_event_processor.dart';
import 'package:test/test.dart';
import 'dart:html' as html show window;

void main() {
  group('web_enricher', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds dart runtime', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event);

      expect(event.contexts.runtimes, isNotEmpty);
      final dartRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Dart');
      expect(dartRuntime.name, 'Dart');
    });

    test('adds browser runtime', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event);

      expect(event.contexts.runtimes, isNotEmpty);
      final dartRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Browser');
      expect(dartRuntime.name, 'Browser');
      expect(dartRuntime.rawDescription, isNotNull);
    });

    test('does add to existing runtimes', () async {
      final runtime = SentryRuntime(name: 'foo', version: 'bar');
      var event = SentryEvent(contexts: Contexts(runtimes: [runtime]));
      var enricher = fixture.getSut();
      event = await enricher.apply(event);

      expect(event.contexts.runtimes.contains(runtime), true);
      expect(event.contexts.runtimes.length, 3);
    });

    test('adds device and os', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event);

      expect(event.contexts.device, isNotNull);
      expect(event.contexts.operatingSystem, isNotNull);
    });

    test('device has timezone, screendensity', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event);

      expect(event.contexts.device?.timezone, isNotNull);
      expect(event.contexts.device?.screenDensity, isNotNull);
    });

    test('os has name', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event);

      expect(event.contexts.operatingSystem?.name, isNotNull);
    });

    test('does not override event', () async {
      final fakeEvent = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(
            online: false,
            memorySize: 200,
            orientation: SentryOrientation.landscape,
            screenHeightPixels: 1080,
            screenWidthPixels: 1920,
            screenDensity: 2,
            timezone: 'foo_timezone',
          ),
          operatingSystem: SentryOperatingSystem(
            name: 'sentry_os',
          ),
        ),
      );

      final enricher = fixture.getSut();

      final event = await enricher.apply(fakeEvent);

      // contexts.device
      expect(
        event.contexts.device?.online,
        fakeEvent.contexts.device?.online,
      );
      expect(
        event.contexts.device?.memorySize,
        fakeEvent.contexts.device?.memorySize,
      );
      expect(
        event.contexts.device?.orientation,
        fakeEvent.contexts.device?.orientation,
      );
      expect(
        event.contexts.device?.screenHeightPixels,
        fakeEvent.contexts.device?.screenHeightPixels,
      );
      expect(
        event.contexts.device?.screenWidthPixels,
        fakeEvent.contexts.device?.screenWidthPixels,
      );
      expect(
        event.contexts.device?.screenDensity,
        fakeEvent.contexts.device?.screenDensity,
      );
      expect(
        event.contexts.device?.timezone,
        fakeEvent.contexts.device?.timezone,
      );
      // contexts.operatingSystem
      expect(
        event.contexts.operatingSystem?.name,
        fakeEvent.contexts.operatingSystem?.name,
      );
    });
  });
}

class Fixture {
  SentryEvent event = SentryEvent();

  WebEnricherEventProcessor getSut() {
    return WebEnricherEventProcessor(
      html.window,
      PlatformChecker(),
    );
  }
}
