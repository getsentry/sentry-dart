import 'dart:io';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/sentry_http_client.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group(SentryHttpClient, () {
    test('GET: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get('https://example.com');
      expect(response.statusCode, 200);

      final breadcrumb = verify(mockHub.addBreadcrumb(captureAny))
          .captured
          .single as Breadcrumb;

      expect(breadcrumb.type, 'https');
      expect(breadcrumb.data, <String, dynamic>{
        'url': 'https://example.com',
        'method': 'GET',
        'status_code': 200,
        'reason': 'OK',
      });
    });

    test('GET: happy path with only http', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('http://example.com'));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get('http://example.com');
      expect(response.statusCode, 200);

      final breadcrumb = verify(mockHub.addBreadcrumb(captureAny))
          .captured
          .single as Breadcrumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data, <String, dynamic>{
        'url': 'http://example.com',
        'method': 'GET',
        'status_code': 200,
        'reason': 'OK',
      });
    });

    test('GET: happy path for 404', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 404, reasonPhrase: 'NOT FOUND');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get('https://example.com');
      expect(response.statusCode, 404);

      final breadcrumb = verify(mockHub.addBreadcrumb(captureAny))
          .captured
          .single as Breadcrumb;

      expect(breadcrumb.type, 'https');
      expect(breadcrumb.data, <String, dynamic>{
        'url': 'https://example.com',
        'method': 'GET',
        'status_code': 404,
        'reason': 'NOT FOUND',
      });
    });

    test('POST: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.post('https://example.com');
      expect(response.statusCode, 200);

      final breadcrumb = verify(mockHub.addBreadcrumb(captureAny))
          .captured
          .single as Breadcrumb;

      expect(breadcrumb.type, 'https');
      expect(breadcrumb.data, <String, dynamic>{
        'url': 'https://example.com',
        'method': 'POST',
        'status_code': 200,
      });
    });

    test('PUT: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.put('https://example.com');
      expect(response.statusCode, 200);

      final breadcrumb = verify(mockHub.addBreadcrumb(captureAny))
          .captured
          .single as Breadcrumb;

      expect(breadcrumb.type, 'https');
      expect(breadcrumb.data, <String, dynamic>{
        'url': 'https://example.com',
        'method': 'PUT',
        'status_code': 200,
      });
    });

    test('DELETE: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.delete('https://example.com');
      expect(response.statusCode, 200);

      final breadcrumb = verify(mockHub.addBreadcrumb(captureAny))
          .captured
          .single as Breadcrumb;

      expect(breadcrumb.type, 'https');
      expect(breadcrumb.data, <String, dynamic>{
        'url': 'https://example.com',
        'method': 'DELETE',
        'status_code': 200,
        'reason': 'OK',
      });
    });

    /// Tests, that in case an exception gets thrown, that
    ///   - no breadcrumb gets added
    ///   - no exception gets reported by Sentry, in case the user wants to
    ///     handle the exception
    test('no breadcrumb for ClientException', () async {
      final url = Uri.parse('https://example.com');

      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, url);
        throw ClientException('test', url);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get('https://example.com');
        fail('Method did not throw');
      } on ClientException catch (e) {
        expect(e.message, 'test');
        expect(e.uri, url);
      }

      verifyNever(mockHub.addBreadcrumb(captureAny));
      verifyNever(mockHub.captureException(captureAny));
    });

    /// SocketException are only a thing on dart:io platforms.
    /// otherwise this is equal to the test above
    test('no breadcrumb for SocketException', () async {
      final url = Uri.parse('https://example.com');

      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, url);
        throw SocketException('test');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get('https://example.com');
        fail('Method did not throw');
      } on SocketException catch (e) {
        expect(e.message, 'test');
      }

      verifyNever(mockHub.addBreadcrumb(captureAny));
      verifyNever(mockHub.captureException(captureAny));
    });

    test('close does not get called for user defined client', () async {
      final mockHub = MockHub();

      final mockClient = CloseableMockClient();

      final client = SentryHttpClient(client: mockClient, hub: mockHub);
      client.close();

      verifyNever(mockHub.addBreadcrumb(captureAny));
      verifyNever(mockHub.captureException(captureAny));
      verifyNever(mockClient.close());
    });
  });
}

class CloseableMockClient extends Mock implements BaseClient {}
