import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/transport/http_transport.dart';
import 'package:sentry/src/transport/rate_limiter.dart';
import 'package:sentry/src/transport/spotlight_http_transport.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../mocks.dart';
import '../mocks/mock_client_report_recorder.dart';
import '../test_utils.dart';

void main() {
  group('send to Sentry', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('send event to Sentry even if Spotlight fails', () async {
      List<int>? body;

      final httpMock = MockClient((http.Request request) async {
        body = request.bodyBytes;
        if (request.url.toString() == fixture.options.spotlight.url) {
          return http.Response('{}', 500);
        }
        return http.Response('{}', 200);
      });

      fixture.options.compressPayload = false;
      final mockRateLimiter = MockRateLimiter();
      final sut = fixture.getSut(httpMock, mockRateLimiter);

      final sentryEvent = SentryEvent();
      final envelope = SentryEnvelope.fromEvent(
        sentryEvent,
        fixture.options.sdk,
        dsn: fixture.options.dsn,
      );
      await sut.send(envelope);

      final envelopeData = <int>[];
      await envelope
          .envelopeStream(fixture.options)
          .forEach(envelopeData.addAll);

      expect(body, envelopeData);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  late var clientReportRecorder = MockClientReportRecorder();

  Transport getSut(http.Client client, RateLimiter rateLimiter) {
    options.httpClient = client;
    options.recorder = clientReportRecorder;
    options.clock = () {
      return DateTime.utc(2019);
    };
    final httpTransport = HttpTransport(options, rateLimiter);
    return SpotlightHttpTransport(options, httpTransport);
  }
}
