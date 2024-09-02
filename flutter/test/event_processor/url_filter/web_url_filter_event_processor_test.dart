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
      final event = _createEventWithException("foo.bar");
      fixture.options.allowUrls = ["another.url"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test('returns event if allowUrl is set and does partially match with url',
        () async {
      final event = _createEventWithException("foo.bar");
      fixture.options.allowUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test('returns event if denyUrl is set and does not match with url',
        () async {
      final event = _createEventWithException("foo.bar");
      fixture.options.denyUrls = ["another.url"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test('returns null if denyUrl is set and partially matches with url',
        () async {
      final event = _createEventWithException("foo.bar");
      fixture.options.denyUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test(
        'returns null if it is part of the allowed domain, but blocked for subdomain',
        () async {
      final event = _createEventWithException(
          "this.is/a/special/url/for-testing/this-feature");

      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test(
        'returns event if it is part of the allowed domain, and not of the blocked for subdomain',
        () async {
      final event = _createEventWithException(
          "this.is/a/test/url/for-testing/this-feature");
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test(
        'returns null if it is not part of the allowed domain, and not of the blocked for subdomain',
        () async {
      final event = _createEventWithException(
          "another.url/for/a/test/testing/this-feature");
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNull);
    });

    test(
        'returns event if denyUrl is set and not matching with url of first exception',
        () async {
      final frame1 = SentryStackFrame(absPath: "test.url");
      final st1 = SentryStackTrace(frames: [frame1]);
      final exception1 = SentryException(
          type: "test-type", value: "test-value", stackTrace: st1);

      final frame2 = SentryStackFrame(absPath: "foo.bar");
      final st2 = SentryStackTrace(frames: [frame2]);
      final exception2 = SentryException(
          type: "test-type", value: "test-value", stackTrace: st2);

      SentryEvent event = SentryEvent(exceptions: [exception1, exception2]);

      fixture.options.denyUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });

    test(
        'returns event if denyUrl is set and not matching with url of first stacktraceframe',
        () async {
      final frame1 = SentryStackFrame(absPath: "test.url");
      final st1 = SentryStackTrace(frames: [frame1]);
      final thread1 = SentryThread(stacktrace: st1);

      final frame2 = SentryStackFrame(absPath: "foo.bar");
      final st2 = SentryStackTrace(frames: [frame2]);
      final thread2 = SentryThread(stacktrace: st2);

      SentryEvent event = SentryEvent(threads: [thread1, thread2]);

      fixture.options.denyUrls = ["bar"];

      var eventProcessor = fixture.getSut();
      final processedEvent = await eventProcessor.apply(event, Hint());

      expect(processedEvent, isNotNull);
    });
  });
}

class Fixture {
  SentryFlutterOptions options = SentryFlutterOptions();
  UrlFilterEventProcessor getSut() {
    return UrlFilterEventProcessor(options);
  }
}

SentryEvent _createEventWithException(String url) {
  final frame = SentryStackFrame(absPath: url);
  final st = SentryStackTrace(frames: [frame]);
  final exception =
      SentryException(type: "test-type", value: "test-value", stackTrace: st);
  SentryEvent event = SentryEvent(exceptions: [exception]);

  return event;
}
