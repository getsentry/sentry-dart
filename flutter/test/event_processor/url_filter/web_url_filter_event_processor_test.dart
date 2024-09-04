@TestOn('browser')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/url_filter/url_filter_event_processor.dart';

// can be tested on command line with
// `flutter test --platform=chrome test/event_processor/url_filter/web_url_filter_event_processor_test.dart`
// The URL looks something like this: http://localhost:58551/event_processor/url_filter/web_url_filter_event_processor_test.html

void main() {
  group(UrlFilterEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns event if no allowUrl and no denyUrl is set', () async {
      final event = SentryEvent();
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test('returns null if allowUrl is set and does not match with url',
        () async {
      final event = SentryEvent();
      fixture.options.allowUrls = ["another.url"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test('returns event if allowUrl is set and does partially match with url',
        () async {
      final event = SentryEvent();
      fixture.options.allowUrls = ["event_processor_test"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test('returns event if denyUrl is set and does not match with url',
        () async {
      final event = SentryEvent();
      fixture.options.denyUrls = ["another.url"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test('returns null if denyUrl is set and partially matches with url',
        () async {
      final event = SentryEvent();
      fixture.options.denyUrls = ["event_processor_test"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test(
        'returns null if it is part of the allowed domain, but blocked for subdomain',
        () async {
      final event = SentryEvent();
      fixture.options.allowUrls = [".*localhost.*\$"];
      fixture.options.denyUrls = ["event"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test(
        'returns event if it is part of the allowed domain, and not of the blocked for subdomain',
        () async {
      final event = SentryEvent();
      fixture.options.allowUrls = [".*localhost.*\$"];
      fixture.options.denyUrls = ["special"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test(
        'returns null if it is not part of the allowed domain, and not of the blocked for subdomain',
        () async {
      final event = SentryEvent();
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];
      final eventProcessor = fixture.getSut();

      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });
  });
}

class Fixture {
  SentryFlutterOptions options = SentryFlutterOptions();
  UrlFilterEventProcessor getSut() {
    return UrlFilterEventProcessor(options);
  }
}
