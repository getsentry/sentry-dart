@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry/src/enricher/_io_enricher.dart';
import 'package:test/test.dart';

void main() {
  group('io_enricher', () {
    late var fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('Enricher is IoEnricher on VM', () {
      final enricher = Enricher();
      expect(enricher, isA<IoEnricher>());
    });

    test('adds dart runtime', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.runtimes, isNotEmpty);
      final dartRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Dart');
      expect(dartRuntime.name, 'Dart');
      expect(dartRuntime.version, isNotNull);
    });

    test('does add to existing runtimes', () async {
      final runtime = SentryRuntime(name: 'foo', version: 'bar');
      var event = SentryEvent(contexts: Contexts(runtimes: [runtime]));
      final enricher = fixture.getSut();

      event = await enricher.apply(event, false);

      expect(event.contexts.runtimes.contains(runtime), true);
      // second runtime is Dart runtime
      expect(event.contexts.runtimes.length, 2);
    });

    test('does not add device and os if native integration is available',
        () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, true);

      expect(event.contexts.device, isNull);
      expect(event.contexts.operatingSystem, isNull);
    });

    test('adds device and os if no native integration is available', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.device, isNotNull);
      expect(event.contexts.operatingSystem, isNotNull);
    });

    test('device has language, name and timezone', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.device?.language, isNotNull);
      expect(event.contexts.device?.name, isNotNull);
      expect(event.contexts.device?.timezone, isNotNull);
    });

    test('os has name and version', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      expect(event.contexts.operatingSystem?.name, isNotNull);
      expect(event.contexts.operatingSystem?.version, isNotNull);
    });

    test('adds Dart context', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(fixture.event, false);

      final dartContext = event.contexts['dart_context'];
      expect(dartContext, isNotNull);
      expect(dartContext['number_of_processors'], isNotNull);
      expect(dartContext['executable'], isNotNull);
      expect(dartContext['resolved_executable'], isNotNull);
      expect(dartContext['script'], isNotNull);
      // package_config and executable_arguments are optional
    });
  });
}

class Fixture {
  SentryEvent event = SentryEvent();
  IoEnricher enricher = IoEnricher();

  IoEnricher getSut() {
    return enricher;
  }
}
