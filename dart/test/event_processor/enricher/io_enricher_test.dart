@TestOn('vm')
library;

import 'dart:io';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/enricher/io_enricher_event_processor.dart';
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:test/test.dart';

import '../../mocks.dart';
import '../../test_utils.dart';

void main() {
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
    expect(dartRuntime!.version.toString(), isNot(Platform.version));
    expect(Platform.version, contains(dartRuntime.version.toString()));
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

  group('adds device, os and culture', () {
    for (final hasNativeIntegration in [true, false]) {
      test('native=$hasNativeIntegration', () {
        final enricher =
            fixture.getSut(hasNativeIntegration: hasNativeIntegration);
        final event = enricher.apply(SentryEvent(), Hint());

        expect(event?.contexts.device, isNotNull);
        expect(event?.contexts.operatingSystem, isNotNull);
        expect(event?.contexts.culture, isNotNull);
      });
    }
  });

  test('device has no name if sendDefaultPii = false', () {
    final enricher = fixture.getSut();
    final event = enricher.apply(SentryEvent(), Hint());

    expect(event?.contexts.device?.name, isNull);
  });

  test('device has name if sendDefaultPii = true', () {
    final enricher = fixture.getSut(includePii: true);
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
    if (Platform.isLinux) {
      expect(event?.contexts.operatingSystem?.kernelVersion, isNotNull);
    } else {
      expect(event?.contexts.operatingSystem?.version, isNotNull);
    }
  });

  group('os info parsing', () {
    // See docs from [Platform.operatingSystemVersion]:
    /// A string representing the version of the operating system or platform.
    ///
    /// The format of this string will vary by operating system, platform and
    /// version and is not suitable for parsing. For example:
    ///   "Linux 5.11.0-1018-gcp #20~20.04.2-Ubuntu SMP Fri Sep 3 01:01:37 UTC 2021"
    ///   "Version 14.5 (Build 18E182)"
    ///   '"Windows 10 Pro" 10.0 (Build 19043)'

    Map<String, dynamic> parse(String name, String description) =>
        fixture.getSut().extractOperatingSystem(name, description).toJson();

    test('android', () {
      expect(parse('android', 'LYA-L29 10.1.0.289(C432E7R1P5)'), {
        'raw_description': 'LYA-L29 10.1.0.289(C432E7R1P5)',
        'name': 'Android',
        'build': 'LYA-L29 10.1.0.289(C432E7R1P5)',
      });
      expect(parse('android', 'TE1A.220922.010'), {
        'raw_description': 'TE1A.220922.010',
        'name': 'Android',
        'build': 'TE1A.220922.010',
      });
    });

    test('linux', () {
      expect(
          parse('linux',
              'Linux 5.11.0-1018-gcp #20~20.04.2-Ubuntu SMP Fri Sep 3 01:01:37 UTC 2021'),
          {
            'raw_description':
                'Linux 5.11.0-1018-gcp #20~20.04.2-Ubuntu SMP Fri Sep 3 01:01:37 UTC 2021',
            'name': 'Linux',
            'kernel_version': '5.11.0-1018-gcp',
            'build': '#20~20.04.2-Ubuntu SMP Fri Sep 3 01:01:37 UTC 2021',
          });
    });

    test('ios', () {
      expect(parse('ios', 'Version 14.5 (Build 18E182)'), {
        'raw_description': 'Version 14.5 (Build 18E182)',
        'name': 'iOS',
        'version': '14.5',
        'build': '18E182',
      });
    });

    test('macos', () {
      expect(parse('macos', 'Version 14.5 (Build 18E182)'), {
        'raw_description': 'Version 14.5 (Build 18E182)',
        'name': 'macOS',
        'version': '14.5',
        'build': '18E182',
      });
    });

    test('windows', () {
      expect(parse('windows', '"Windows 10 Pro" 10.0 (Build 19043)'), {
        'raw_description': '"Windows 10 Pro" 10.0 (Build 19043)',
        'name': 'Windows',
        'version': '10.0',
        'build': '19043',
      });
    });
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
    final options = defaultTestOptions();
    await Sentry.init(
      (options) {
        options.dsn = fakeDsn;
      },
      options: options,
    );
    await Sentry.close();

    final ioEnricherCount =
        options.eventProcessors.whereType<IoEnricherEventProcessor>().length;
    expect(ioEnricherCount, 1);
  });
}

class Fixture {
  IoEnricherEventProcessor getSut({
    bool hasNativeIntegration = false,
    bool includePii = false,
  }) {
    final options = defaultTestOptions()
      ..platform =
          hasNativeIntegration ? MockPlatform.iOS() : MockPlatform.fuchsia()
      ..sendDefaultPii = includePii;

    return IoEnricherEventProcessor(options);
  }
}
