@TestOn('browser')
library dart_test;

import 'dart:html' as html;

import 'package:sentry/sentry.dart';
import 'package:sentry/src/event_processor/enricher/web_enricher_event_processor.dart';
import 'package:test/test.dart';

import '../../mocks.dart';
import '../../mocks/mock_platform_checker.dart';

// can be tested on command line with
// `dart test -p chrome --name web_enricher`
void main() {
  group('web_enricher', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('add path as transaction if transaction is null', () {
      var enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.transaction, isNotNull);
    });

    test("don't overwrite transaction", () {
      var enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(transaction: 'foobar'), Hint());

      expect(event?.transaction, 'foobar');
    });

    test('add request with user-agent header', () {
      var enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.request?.headers['User-Agent'], isNotNull);
      expect(event?.request?.url, isNotNull);
    });

    test('adds header to request if request already exists', () {
      var event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
          headers: {
            'foo': 'bar',
          },
        ),
      );
      var enricher = fixture.getSut();
      event = enricher.apply(event, Hint())!;

      expect(event.request?.headers['User-Agent'], isNotNull);
      expect(event.request?.headers['foo'], 'bar');
      expect(event.request?.url, 'foo.bar');
    });

    test('does not add auth headers to request', () {
      var event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
          headers: {
            'Authorization': 'foo',
            'authorization': 'bar',
          },
        ),
      );
      var enricher = fixture.getSut();
      event = enricher.apply(event, Hint())!;

      expect(event.request?.headers['Authorization'], isNull);
      expect(event.request?.headers['authorization'], isNull);
    });

    test('user-agent is not overridden if already present', () {
      var event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
          headers: {
            'User-Agent': 'best browser agent',
          },
        ),
      );
      var enricher = fixture.getSut();
      event = enricher.apply(event, Hint())!;

      expect(event.request?.headers['User-Agent'], 'best browser agent');
      expect(event.request?.url, 'foo.bar');
    });

    test('adds device and os', () {
      var enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device, isNotNull);
    });

    test('adds Dart context', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      final dartContext = event?.contexts['dart_context'];
      expect(dartContext, isNotNull);
      expect(dartContext['compile_mode'], isNotNull);
    });

    test('device has screendensity', () {
      var enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.device?.screenDensity, isNotNull);
    });

    test('culture has timezone', () {
      var enricher = fixture.getSut();
      final event = enricher.apply(SentryEvent(), Hint());

      expect(event?.contexts.culture?.timezone, isNotNull);
    });

    test('does not override event', () {
      final fakeEvent = SentryEvent(
        contexts: Contexts(
          device: SentryDevice(
            online: false,
            memorySize: 200,
            orientation: SentryOrientation.landscape,
            screenHeightPixels: 1080,
            screenWidthPixels: 1920,
            screenDensity: 2,
          ),
          operatingSystem: SentryOperatingSystem(
            name: 'sentry_os',
          ),
          culture: SentryCulture(
            timezone: 'foo_timezone',
          ),
        ),
      );

      final enricher = fixture.getSut();

      final event = enricher.apply(fakeEvent, Hint());

      // contexts.device
      expect(
        event?.contexts.device?.online,
        fakeEvent.contexts.device?.online,
      );
      expect(
        event?.contexts.device?.memorySize,
        fakeEvent.contexts.device?.memorySize,
      );
      expect(
        event?.contexts.device?.orientation,
        fakeEvent.contexts.device?.orientation,
      );
      expect(
        event?.contexts.device?.screenHeightPixels,
        fakeEvent.contexts.device?.screenHeightPixels,
      );
      expect(
        event?.contexts.device?.screenWidthPixels,
        fakeEvent.contexts.device?.screenWidthPixels,
      );
      expect(
        event?.contexts.device?.screenDensity,
        fakeEvent.contexts.device?.screenDensity,
      );
      // contexts.culture
      expect(
        event?.contexts.culture?.timezone,
        fakeEvent.contexts.culture?.timezone,
      );
      // contexts.operatingSystem
      expect(
        event?.contexts.operatingSystem?.name,
        fakeEvent.contexts.operatingSystem?.name,
      );
    });

    test('$WebEnricherEventProcessor gets added on init', () async {
      late SentryOptions sentryOptions;
      await Sentry.init(
        (options) {
          options.dsn = fakeDsn;
          sentryOptions = options;
        },
      );
      await Sentry.close();

      final ioEnricherCount = sentryOptions.eventProcessors
          .whereType<WebEnricherEventProcessor>()
          .length;
      expect(ioEnricherCount, 1);
    });
  });
}

class Fixture {
  WebEnricherEventProcessor getSut() {
    final options = SentryOptions(
        dsn: fakeDsn,
        checker: MockPlatformChecker(hasNativeIntegration: false));

    return WebEnricherEventProcessor(
      html.window,
      options,
    );
  }
}
