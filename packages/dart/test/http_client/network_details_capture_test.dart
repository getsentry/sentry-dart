import 'package:http/http.dart';
import 'package:sentry/src/http_client/network_details_capture.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('$NetworkDetailsCapture', () {
    group('shouldCapture', () {
      test('returns false when disabled by default', () {
        final fixture = Fixture();
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://example.com')), false);
      });

      test('returns false when enabled but allow list is empty', () {
        final fixture = Fixture();
        fixture.options.enableReplayNetworkDetailsCapturing = true;
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://example.com')), false);
      });

      test('returns true when enabled and url matches allow list', () {
        final fixture = Fixture();
        fixture.options.enableReplayNetworkDetailsCapturing = true;
        fixture.options.networkDetailAllowUrls.add('example.com');
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://example.com/path')), true);
      });

      test('returns false when url does not match allow list', () {
        final fixture = Fixture();
        fixture.options.enableReplayNetworkDetailsCapturing = true;
        fixture.options.networkDetailAllowUrls.add('example.com');
        final sut = fixture.getSut();

        expect(sut.shouldCapture(Uri.parse('https://other.com')), false);
      });

      test('deny list overrides allow list', () {
        final fixture = Fixture();
        fixture.options.enableReplayNetworkDetailsCapturing = true;
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

      test('captures additional configured request headers', () {
        final fixture = Fixture();
        fixture.options.networkRequestHeaders.add('X-Custom');
        final sut = fixture.getSut();

        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll({'X-Custom': 'value'});

        final data = sut.captureRequest(request);

        expect(data['headers'], {'X-Custom': 'value'});
      });

      test('captures body for capturable content type', () {
        final fixture = Fixture();
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/json'
          ..body = '{"foo":"bar"}';

        final data = sut.captureRequest(request);

        expect(data['body'], '{"foo":"bar"}');
      });

      test('does not capture body for non-capturable content type', () {
        final fixture = Fixture();
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/octet-stream'
          ..bodyBytes = [1, 2, 3];

        final data = sut.captureRequest(request);

        expect(data.containsKey('body'), false);
      });

      test('does not capture body when networkCaptureBodies is false', () {
        final fixture = Fixture();
        fixture.options.networkCaptureBodies = false;
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'application/json'
          ..body = '{"foo":"bar"}';

        final data = sut.captureRequest(request);

        expect(data.containsKey('body'), false);
      });

      test('truncates request body at max size', () {
        final fixture = Fixture();
        final sut = fixture.getSut();

        final request = Request('POST', Uri.parse('https://example.com'))
          ..headers['content-type'] = 'text/plain'
          ..body = 'a' * (NetworkDetailsCapture.maxBodySize + 100);

        final data = sut.captureRequest(request);

        expect(
            (data['body'] as String).length, NetworkDetailsCapture.maxBodySize);
      });
    });

    group('captureResponse', () {
      test('captures headers and body, and forwards full body downstream',
          () async {
        final fixture = Fixture();
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
    });
  });
}

class Fixture {
  final options = defaultTestOptions();

  NetworkDetailsCapture getSut() => NetworkDetailsCapture(options);
}
