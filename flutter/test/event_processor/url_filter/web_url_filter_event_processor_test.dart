@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/url_filter/url_filter_event_processor.dart';

// can be tested on command line with
// `flutter test --platform=chrome test/event_processor/url_filter/web_url_filter_event_processor_test.dart`
void main() {
  group(UrlFilterEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns event if no allowUrl and no denyUrl is set', () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test('returns null if allowUrl is set and does not match with url',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.allowUrls = ["another.url"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });

    test('returns event if allowUrl is set and does partially match with url',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.allowUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test('returns event if denyUrl is set and does not match with url',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.denyUrls = ["another.url"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test('returns null if denyUrl is set and partially matches with url',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'foo.bar',
        ),
      );
      fixture.options.denyUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });

    test(
        'returns null if it is part of the allowed domain, but blocked for subdomain',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'this.is/a/special/url/for-testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });

    test(
        'returns event if it is part of the allowed domain, and not of the blocked for subdomain',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'this.is/a/test/url/for-testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });

    test(
        'returns null if it is not part of the allowed domain, and not of the blocked for subdomain',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'another.url/for/a/test/testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNull);
    });
  });
}

class Fixture {
  SentryFlutterOptions options = SentryFlutterOptions();
  UrlFilterEventProcessor getSut() {
    return UrlFilterEventProcessor(options);
  }
}
