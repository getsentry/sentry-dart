@TestOn('browser')
import 'package:sentry/sentry.dart';
import 'package:sentry/src/enricher/_web_enricher.dart';
import 'package:test/test.dart';
import 'dart:html' as html show window;

void main() {
  group('web_enricher', () {
    late var fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('Enricher is IoEnricher on VM', () {
      final enricher = Enricher();
      expect(enricher, isA<WebEnricher>());
    });

    test('adds dart runtime', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.runtimes, isNotEmpty);
      final dartRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Dart') as SentryRuntime;
      expect(dartRuntime.name, 'Dart');
    });

    test('adds browser runtime', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.runtimes, isNotEmpty);
      final dartRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Browser') as SentryRuntime;
      expect(dartRuntime.name, 'Browser');
      expect(dartRuntime.rawDescription, isNotNull);
    });

    test('does add to existing runtimes', () async {
      final runtime = SentryRuntime(name: 'foo', version: 'bar');
      var event = SentryEvent(contexts: Contexts(runtimes: [runtime]));
      var enricher = fixture.getSut();
      event = await enricher.apply(event, false);

      expect(event.contexts.runtimes.contains(runtime), true);
      expect(event.contexts.runtimes.length, 3);
    });

    test('adds device and os', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.device, isNotNull);
      expect(event.contexts.operatingSystem, isNotNull);
    });

    test('device has timezone, screendensity', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.device?.timezone, isNotNull);
      expect(event.contexts.device?.screenDensity, isNotNull);
    });

    test('os has name', () async {
      var enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.operatingSystem?.name, isNotNull);
    });
  });
}

class Fixture {
  SentryEvent event = SentryEvent();

  WebEnricher getSut() {
    return WebEnricher(
      html.window,
      PlatformChecker(),
    );
  }
}
