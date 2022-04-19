@TestOn('vm')

import 'package:sentry/sentry.dart';
import 'package:sentry/src/enricher/io_enricher_event_processor.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_platform_checker.dart';

void main() {
  group('io_enricher', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds dart runtime', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(SentryEvent());

      expect(event.contexts.runtimes, isNotEmpty);
      final dartRuntime = event.contexts.runtimes
          .firstWhere((element) => element.name == 'Dart');
      expect(dartRuntime.name, 'Dart');
      expect(dartRuntime.rawDescription, isNotNull);
    });

    test('does add to existing runtimes', () async {
      final runtime = SentryRuntime(name: 'foo', version: 'bar');
      var event = SentryEvent(contexts: Contexts(runtimes: [runtime]));
      final enricher = fixture.getSut();

      event = await enricher.apply(event);

      expect(event.contexts.runtimes.contains(runtime), true);
      // second runtime is Dart runtime
      expect(event.contexts.runtimes.length, 2);
    });

    test('does not add device and os if native integration is available',
        () async {
      final enricher = fixture.getSut(hasNativeIntegration: true);
      final event = await enricher.apply(SentryEvent());

      expect(event.contexts.device, isNull);
      expect(event.contexts.operatingSystem, isNull);
    });

    test('adds device and os if no native integration is available', () async {
      final enricher = fixture.getSut(hasNativeIntegration: false);
      final event = await enricher.apply(SentryEvent());

      expect(event.contexts.device, isNotNull);
      expect(event.contexts.operatingSystem, isNotNull);
    });

    test('device has language, name and timezone', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(SentryEvent());

      expect(event.contexts.device?.language, isNotNull);
      expect(event.contexts.device?.name, isNotNull);
      expect(event.contexts.device?.timezone, isNotNull);
    });

    test('os has name and version', () async {
      final enricher = fixture.getSut();
      final event = await enricher.apply(SentryEvent());

      expect(event.contexts.operatingSystem?.name, isNotNull);
      expect(event.contexts.operatingSystem?.version, isNotNull);
    });

    test('adds Dart context with PII', () async {
      final enricher = fixture.getSut(includePii: true);
      final event = await enricher.apply(SentryEvent());

      final dartContext = event.contexts['dart_context'];
      expect(dartContext, isNotNull);
      expect(dartContext['isolate'], isNotNull);
      expect(dartContext['number_of_processors'], isNotNull);
      // Getting the executable sometimes throws
      //expect(dartContext['executable'], isNotNull);
      expect(dartContext['resolved_executable'], isNotNull);
      expect(dartContext['script'], isNotNull);
      // package_config and executable_arguments are optional
    });

    test('adds Dart context without PII', () async {
      final enricher = fixture.getSut(includePii: false);
      final event = await enricher.apply(SentryEvent());

      final dartContext = event.contexts['dart_context'];
      expect(dartContext, isNotNull);
      expect(dartContext['compile_mode'], isNotNull);
      expect(dartContext['number_of_processors'], isNotNull);
      expect(dartContext['isolate'], isNotNull);
      expect(dartContext['executable'], isNull);
      expect(dartContext['resolved_executable'], isNull);
      expect(dartContext['script'], isNull);
      // package_config and executable_arguments are optional
      // and Platform is not mockable
    });

    test('does not override event', () async {
      final fakeEvent = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(
            language: 'foo_bar_language',
            name: 'device_name',
            timezone: 'foo_timezone',
          ),
          operatingSystem: SentryOperatingSystem(
            name: 'sentry_os',
            version: 'best version',
          ),
        ),
      );

      final enricher = fixture.getSut(
        includePii: true,
        hasNativeIntegration: false,
      );

      final event = await enricher.apply(fakeEvent);

      // contexts.device
      expect(
        event.contexts.device?.language,
        fakeEvent.contexts.device?.language,
      );
      expect(
        event.contexts.device?.name,
        fakeEvent.contexts.device?.name,
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
      expect(
        event.contexts.operatingSystem?.version,
        fakeEvent.contexts.operatingSystem?.version,
      );
    });

    test('$IoEnricherEventProcessor gets added on init', () async {
      late SentryOptions sentryOptions;
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          sentryOptions = options;
        },
      );
      await Sentry.close();

      final ioEnricherCount = sentryOptions.eventProcessors
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
