@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/event_processor/url_filter/url_filter_event_processor.dart';

import '../../mocks.dart';

void main() {
  group("ignore allowUrls and denyUrls for non Web", () {
    late Fixture fixture;

    setUp(() async {
      fixture = Fixture();
    });

    test('returns the event and ignore allowUrls and denyUrls for non Web',
        () async {
      SentryEvent? event = SentryEvent(
        request: SentryRequest(
          url: 'another.url/for/a/special/test/testing/this-feature',
        ),
      );
      fixture.options.allowUrls = ["^this.is/.*\$"];
      fixture.options.denyUrls = ["special"];

      var eventProcessor = fixture.getSut();
      event = await eventProcessor.apply(event, Hint());

      expect(event, isNotNull);
    });
  });
}

class Fixture {
  SentryFlutterOptions options = defaultTestOptions();
  UrlFilterEventProcessor getSut() {
    return UrlFilterEventProcessor(options);
  }
}
