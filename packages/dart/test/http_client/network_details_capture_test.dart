import 'package:http/http.dart';
import 'package:sentry/src/constants.dart';
import 'package:sentry/src/http_client/network_details_capture.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('$NetworkDetailsCapture', () {
    test('adds feature flag when allow list is non-empty', () {
      final fixture = Fixture();
      fixture.options.networkDetailAllowUrls.add('example.com');

      fixture.getSut();

      expect(fixture.options.sdk.features,
          contains(SentryFeatures.replayNetworkDetailsCapturing));
    });

    test('does not add feature flag when allow list is empty', () {
      final fixture = Fixture();

      fixture.getSut();

      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.replayNetworkDetailsCapturing)));
    });

    group('shouldCapture', () {
      test('returns false when allow list is empty by default', () {
        final fixture = Fixture();
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://example.com')), false);
      });

      test('returns true when url matches allow list', () {
        final fixture = Fixture();
        fixture.options.networkDetailAllowUrls.add('example.com');
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://example.com/path')), true);
      });

      test('returns false when url does not match allow list', () {
        final fixture = Fixture();
        fixture.options.networkDetailAllowUrls.add('example.com');
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://other.com')), false);
      });

      test('deny list overrides allow list', () {
        final fixture = Fixture();
        fixture.options.networkDetailAllowUrls.add('.*');
        fixture.options.networkDetailDenyUrls.add('example.com');
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://example.com')), false);
      });
    });

    group('captureRequest', () {
      test('captures default headers only', () {
        final fixture = Fixture();
        final sut = fixture.getSut();

        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Accept': '*/*',
            'Authorization': 'Bearer secret',
          });

        final data = sut.captureRequest(request);

        expect(data['headers'], {
          'Content-Type': 'application/json',
          'Accept': '*/*',
        });
      });

      test(
          'captures additional configured request headers when sendDefaultPii is enabled',
          () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        fixture.options.networkRequestHeaders.add('X-Custom');
        final sut = fixture.getSut();

        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll({'X-Custom': 'value'});

        final data = sut.captureRequest(request);

        expect(data['headers'], {'X-Custom': 'value'});
      });

      test(
          'does not capture additional configured request headers when sendDefaultPii is disabled',
          () {
        final fixture = Fixture();
        fixture.options.networkRequestHeaders.add('X-Custom');
        final sut = fixture.getSut();

        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll({
            'X-Custom': 'value',
            'Content-Type': 'application/json',
          });

        final data = sut.captureRequest(request);

        expect(data['headers'], {'Content-Type': 'application/json'});
      });

      test('captures body for capturable content type', () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/json'
          ..body = '{"foo":"bar"}';

        final data = sut.captureRequest(request);

        expect(data['body'], '{"foo":"bar"}');
      });

      test('does not capture body for non-capturable content type', () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/octet-stream'
          ..bodyBytes = [1, 2, 3];

        final data = sut.captureRequest(request);

        expect(data.containsKey('body'), false);
      });

      test('does not capture body when networkCaptureBodies is false', () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        fixture.options.networkCaptureBodies = false;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/json'
          ..body = '{"foo":"bar"}';

        final data = sut.captureRequest(request);

        expect(data.containsKey('body'), false);
      });

      test('does not capture body when sendDefaultPii is false', () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = false;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/json'
          ..body = '{"foo":"bar"}';

        final data = sut.captureRequest(request);

        expect(data.containsKey('body'), false);
      });

      test('captures request body up to and including max size', () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'text/plain'
          ..body = 'a' * NetworkDetailsCapture.maxBodySize;

        final data = sut.captureRequest(request);

        expect(
            (data['body'] as String).length, NetworkDetailsCapture.maxBodySize);
      });

      test('does not capture request body exceeding max size', () {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'text/plain'
          ..body = 'a' * (NetworkDetailsCapture.maxBodySize + 100);

        final data = sut.captureRequest(request);

        expect(data.containsKey('body'), false);
      });
    });

    group('captureResponse', () {
      test('captures headers and body, and forwards full body downstream',
          () async {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final response = StreamedResponse(
          Stream.fromIterable([
            'partial-'.codeUnits,
            'body'.codeUnits,
          ]),
          200,
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer secret',
          },
        );

        final (forwardedResponse, data) = await sut.captureResponse(response);

        expect(data['headers'], {'content-type': 'application/json'});
        expect(data['body'], 'partial-body');
        expect(await forwardedResponse.stream.bytesToString(), 'partial-body');
      });

      test('does not capture body for non-capturable content type', () async {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final response = StreamedResponse(
          Stream.value('binary'.codeUnits),
          200,
          headers: {'content-type': 'application/octet-stream'},
        );

        final (forwardedResponse, data) = await sut.captureResponse(response);

        expect(data.containsKey('body'), false);
        expect(await forwardedResponse.stream.bytesToString(), 'binary');
      });

      test('does not capture body when sendDefaultPii is false', () async {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = false;
        final sut = fixture.getSut();

        final response = StreamedResponse(
          Stream.value('{"foo":"bar"}'.codeUnits),
          200,
          headers: {'content-type': 'application/json'},
        );

        final (forwardedResponse, data) = await sut.captureResponse(response);

        expect(data.containsKey('body'), false);
        expect(await forwardedResponse.stream.bytesToString(), '{"foo":"bar"}');
      });

      test('does not capture body when contentLength exceeds max size',
          () async {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final response = StreamedResponse(
          Stream.value('{"foo":"bar"}'.codeUnits),
          200,
          contentLength: NetworkDetailsCapture.maxBodySize + 1,
          headers: {'content-type': 'application/json'},
        );

        final (forwardedResponse, data) = await sut.captureResponse(response);

        expect(data.containsKey('body'), false);
        expect(await forwardedResponse.stream.bytesToString(), '{"foo":"bar"}');
      });

      test(
          'truncates and forwards body exceeding max size when contentLength is unknown',
          () async {
        final fixture = Fixture();
        fixture.options.sendDefaultPii = true;
        final sut = fixture.getSut();

        final oversizedBody = 'a' * (NetworkDetailsCapture.maxBodySize + 100);
        // Split into chunks so the body is read incrementally rather than
        // available as a single value, matching a real chunked response.
        final chunks = [
          for (var i = 0; i < oversizedBody.length; i += 1024)
            oversizedBody
                .substring(
                    i,
                    i + 1024 > oversizedBody.length
                        ? oversizedBody.length
                        : i + 1024)
                .codeUnits,
        ];
        final response = StreamedResponse(
          Stream.fromIterable(chunks),
          200,
          headers: {'content-type': 'text/plain'},
        );

        final (forwardedResponse, data) = await sut.captureResponse(response);

        expect(
            (data['body'] as String).length, NetworkDetailsCapture.maxBodySize);
        expect(await forwardedResponse.stream.bytesToString(), oversizedBody);
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  NetworkDetailsCapture getSut() => NetworkDetailsCapture(options);
}
