import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_dio/src/breadcrumb_client_adapter.dart';
import 'package:test/test.dart';

import 'mocks/mock_http_client_adapter.dart';
import 'mocks/mock_hub.dart';

void main() {
  group(BreadcrumbClientAdapter, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('GET: happy path', () async {
      final sut =
          fixture.getSut(fixture.getClient(statusCode: 200, reason: 'OK'));

      final response = await sut.get<dynamic>('');
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.data?['http.query'], 'foo=bar');
      expect(breadcrumb.data?['http.fragment'], 'baz');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['reason'], null);
      expect(breadcrumb.data?['duration'], isNotNull);
      expect(breadcrumb.data?['request_body_size'], isNull);
      expect(breadcrumb.data?['response_body_size'], isNull);
    });

    test('POST: happy path', () async {
      final sut = fixture.getSut(fixture.getClient(statusCode: 200));

      final response = await sut.post<dynamic>('');
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'POST');
      expect(breadcrumb.data?['http.query'], 'foo=bar');
      expect(breadcrumb.data?['http.fragment'], 'baz');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('PUT: happy path', () async {
      final sut = fixture.getSut(fixture.getClient(statusCode: 200));

      final response = await sut.put<dynamic>('');
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'PUT');
      expect(breadcrumb.data?['http.query'], 'foo=bar');
      expect(breadcrumb.data?['http.fragment'], 'baz');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('DELETE: happy path', () async {
      final sut = fixture.getSut(fixture.getClient(statusCode: 200));

      final response = await sut.delete<dynamic>('');
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'DELETE');
      expect(breadcrumb.data?['http.query'], 'foo=bar');
      expect(breadcrumb.data?['http.fragment'], 'baz');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    /// Tests, that in case an exception gets thrown, that
    /// no exception gets reported by Sentry, in case the user wants to
    /// handle the exception
    test('no captureException for Exception', () async {
      final sut = fixture.getSut(
        MockHttpClientAdapter((options, requestStream, cancelFuture) async {
          expect(options.uri, Uri.parse('https://example.com?foo=bar#baz'));
          throw Exception('test');
        }),
      );

      try {
        await sut.get<dynamic>('');
        fail('Method did not throw');
      } on DioError catch (e) {
        expect(e.error.toString(), 'Exception: test');
        expect(
          e.requestOptions.uri,
          Uri.parse('https://example.com?foo=bar#baz'),
        );
      }

      expect(fixture.hub.captureExceptionCalls.length, 0);
    });

    test('breadcrumb gets added when an exception gets thrown', () async {
      final sut = fixture.getSut(
        MockHttpClientAdapter((options, requestStream, cancelFuture) async {
          expect(options.uri, Uri.parse('https://example.com'));
          throw Exception('foo bar');
        }),
      );

      try {
        await sut.get<dynamic>('');
        fail('Method did not throw');
      } on DioError catch (_) {}

      expect(fixture.hub.addBreadcrumbCalls.length, 1);

      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.data?['http.query'], 'foo=bar');
      expect(breadcrumb.data?['http.fragment'], 'baz');
      expect(breadcrumb.level, SentryLevel.error);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('close does get called for user defined client', () async {
      final mockHub = MockHub();

      final mockClient = CloseableMockClientAdapter();

      final client = BreadcrumbClientAdapter(client: mockClient, hub: mockHub);
      client.close();

      expect(mockHub.addBreadcrumbCalls.length, 0);
      expect(mockHub.captureExceptionCalls.length, 0);
      verify(mockClient.close());
    });

    test('Breadcrumb has correct duration', () async {
      final sut = fixture.getSut(
        MockHttpClientAdapter((options, _, __) async {
          expect(options.uri, Uri.parse('https://example.com?foo=bar#baz'));
          await Future<void>.delayed(Duration(seconds: 1));
          return ResponseBody.fromString('', 200);
        }),
      );

      final response = await sut.get<dynamic>('');
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      final durationString = breadcrumb.data!['duration']! as String;
      // we don't check for anything below a second
      expect(durationString.startsWith('0:00:01'), true);
    });
  });
}

class CloseableMockClientAdapter extends Mock implements HttpClientAdapter {}

class Fixture {
  Dio getSut([MockHttpClientAdapter? client]) {
    final mc = client ?? getClient();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://example.com?foo=bar#baz'),
    );
    dio.httpClientAdapter = BreadcrumbClientAdapter(client: mc, hub: hub);
    return dio;
  }

  late MockHub hub = MockHub();

  MockHttpClientAdapter getClient({int statusCode = 200, String? reason}) {
    return MockHttpClientAdapter((request, requestStream, cancelFuture) async {
      expect(request.uri, Uri.parse('https://example.com?foo=bar#baz'));

      return ResponseBody.fromString(
        '',
        statusCode,
      );
    });
  }
}
