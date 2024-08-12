@TestOn('browser')
library dart_test;

import 'package:sentry/sentry.dart';
import 'package:sentry/sentry_io.dart';
import 'package:sentry/src/event_processor/web_url_filter_event_processor.dart';
import 'package:test/test.dart';

import '../mocks.dart';
import '../mocks/mock_platform_checker.dart';

// can be tested on command line with
// `dart test -p chrome test/event_processor/web_url_filter_event_processor_test.dart --name web_url_filter`
void main() {
  group('web_url_filter', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns event if no allowUrl and no denyUrl is set', () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test('returns null if allowUrl is set and does not match with url', () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.allowUrls = ["another.url"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });

    test('returns event if allowUrl is set and does partially match with url',
        () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.allowUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test('returns event if denyUrl is set and does not match with url', () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.denyUrls = ["another.url"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test('returns null if denyUrl is set and partially matches with url', () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.denyUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });

    test(
        'returns null if it is part of the allowed domain, but blocked for subdomain',
        () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'this.is/a/special/url/for-testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });

    test(
        'returns event if it is part of the allowed domain, and not of the blocked for subdomain',
        () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'this.is/a/test/url/for-testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test(
        'returns null if it is not part of the allowed domain, and not of the blocked for subdomain',
        () {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'another.url/for/a/test/testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });
  });
}

class Fixture {
  SentryOptions options = SentryOptions(
    dsn: fakeDsn,
    checker: MockPlatformChecker(hasNativeIntegration: false),
  );
  WebUrlFilterEventProcessor getSut() {
    return WebUrlFilterEventProcessor(options);
  }
}
