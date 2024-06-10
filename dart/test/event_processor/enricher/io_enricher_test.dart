@TestOn('vm')
library dart_test;

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/enricher/io_enricher_event_processor.dart';
import 'package:test/test.dart';

import '../../mocks.dart';
import '../../mocks/mock_platform_checker.dart';

void main() {
  group('io_enricher', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds dart runtime', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.runtimes, isNotEmpty);
      final dartRuntime = event?.contexts.runtimes
          .firstWhere((element) => element.name == 'Dart');
      expect(dartRuntime?.name, 'Dart');
      expect(dartRuntime?.rawDescription, isNotNull);
    });

    test('does add to existing runtimes', () {
      final runtime = SentryRuntime(name: 'foo', version: 'bar');
      var event = SentryEvent(contexts: Contexts(runtimes: [runtime]));
      final enricher = fixture.getSut();

      event = enricher.apply(event, Hint())!;

      expect(event.contexts.runtimes.contains(runtime), true);
      // second runtime is Dart runtime
      expect(event.contexts.runtimes.length, 2);
    });

    test(
        'does not add device, os and culture if native integration is available',
        () {
      final enricher = fixture.getSut(hasNativeIntegration: true);
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device, isNull);
      expect(event?.contexts.operatingSystem, isNull);
      expect(event?.contexts.culture, isNull);
    });

    test('adds device, os and culture if no native integration is available',
        () {
      final enricher = fixture.getSut(hasNativeIntegration: false);
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device, isNotNull);
      expect(event?.contexts.operatingSystem, isNotNull);
      expect(event?.contexts.culture, isNotNull);
    });

    test('device has name', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device?.name, isNotNull);
    });

    test('culture has locale and timezone', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.culture?.locale, isNotNull);
      expect(event?.contexts.culture?.timezone, isNotNull);
    });

    test('os has name and version', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.operatingSystem?.name, isNotNull);
      expect(event?.contexts.operatingSystem?.version, isNotNull);
    });

    test('adds Dart context with PII', () {
      final enricher = fixture.getSut(includePii: true);
      final event = enricher.apply(SentryEvent(), Hint());

      final dartContext = event?.contexts['dart_context'];
      expect(dartContext, isNotNull);
      // Getting the executable sometimes throws
      //expect(dartContext['executable'], isNotNull);
      expect(dartContext['resolved_executable'], isNotNull);
      expect(dartContext['script'], isNotNull);
      // package_config and executable_arguments are optional
    });

    test('adds Dart context without PII', () {
      final enricher = fixture.getSut(includePii: false);
      final event = enricher.apply(SentryEvent(), Hint());

      final dartContext = event?.contexts['dart_context'];
      expect(dartContext, isNotNull);
      expect(dartContext['compile_mode'], isNotNull);
      expect(dartContext['executable'], isNull);
      expect(dartContext['resolved_executable'], isNull);
      expect(dartContext['script'], isNull);
      // package_config and executable_arguments are optional
      // and Platform is not mockable
    });

    test('does not override event', () {
      final fakeEvent = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(
            name: 'device_name',
          ),
          operatingSystem: SentryOperatingSystem(
            name: 'sentry_os',
            version: 'best version',
          ),
          culture: SentryCulture(
            locale: 'de',
            timezone: 'timezone',
          ),
        ),
      );

      final enricher = fixture.getSut(
        includePii: true,
        hasNativeIntegration: false,
      );

      final event = enricher.apply(fakeEvent, Hint());

      // contexts.device
      expect(
        event?.contexts.device?.name,
        fakeEvent.contexts.device?.name,
      );
      // contexts.culture
      expect(
        event?.contexts.culture?.locale,
        fakeEvent.contexts.culture?.locale,
      );
      expect(
        event?.contexts.culture?.timezone,
        fakeEvent.contexts.culture?.timezone,
      );
      // contexts.operatingSystem
      expect(
        event?.contexts.operatingSystem?.name,
        fakeEvent.contexts.operatingSystem?.name,
      );
      expect(
        event?.contexts.operatingSystem?.version,
        fakeEvent.contexts.operatingSystem?.version,
      );
    });

    test('$IoEnricherEventProcessor gets added on init', () async {
      final options = SentryOptions(dsn: fakeDsn)..automatedTestMode = true;
      late SentryOptions configuredOptions;
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          configuredOptions = options;
        },
        options: options,
      );
      await Sentry.close();

      final ioEnricherCount = configuredOptions.eventProcessors
          .whereType<IoEnricherEventProcessor>()
          .length;
      expect(ioEnricherCount, 1);
    });
  });
}

class Fixture {
  IoEnricherEventProcessor getSut({
    bool hasNativeIntegration = false,
    bool includePii = false,
  }) {
    final options = SentryOptions(
        dsn: fakeDsn,
        checker:
            MockPlatformChecker(hasNativeIntegration: hasNativeIntegration))
      ..sendDefaultPii = includePii;

    return IoEnricherEventProcessor(options);
  }
}
