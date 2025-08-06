import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/event_processor/flutter_exception_event_processor.dart';

void main() {
  group(FlutterExceptionEventProcessor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds $SentryRequest for $NetworkImageLoadException with uris', () {
      final enricher = fixture.getSut();
      final event = enricher.apply(
        SentryEvent(
          throwable: NetworkImageLoadException(
            statusCode: 401,
            uri: Uri.parse('https://example.org/foo/bar?foo=bar'),
          ),
        ),
        Hint(),
      );

      expect(event?.request, isNotNull);
      expect(event?.request?.url, 'https://example.org/foo/bar');
      expect(event?.request?.queryString, 'foo=bar');
    });
  });
}

class Fixture {
  FlutterExceptionEventProcessor getSut() {
    return FlutterExceptionEventProcessor();
  }
}
