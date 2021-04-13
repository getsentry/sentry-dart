import 'dart:io';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/sentry_http_client.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';

void main() {
  group(SentryHttpClient, () {
    test('GET: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get(Uri.parse('https://example.com'));
      expect(response.statusCode, 200);

      expect(mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['reason'], 'OK');
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('GET: happy path for 404', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 404, reasonPhrase: 'NOT FOUND');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get(Uri.parse('https://example.com'));
      expect(response.statusCode, 404);

      expect(mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.data?['status_code'], 404);
      expect(breadcrumb.data?['reason'], 'NOT FOUND');
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('POST: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.post(Uri.parse('https://example.com'));
      expect(response.statusCode, 200);

      expect(mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'POST');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('PUT: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.put(Uri.parse('https://example.com'));
      expect(response.statusCode, 200);

      expect(mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'PUT');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['reason'], 'NOT FOUND');
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('DELETE: happy path', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.delete(Uri.parse('https://example.com'));
      expect(response.statusCode, 200);

      expect(mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'DELETE');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    /// Tests, that in case an exception gets thrown, that
    /// no exception gets reported by Sentry, in case the user wants to
    /// handle the exception
    test('no captureException for ClientException', () async {
      final url = Uri.parse('https://example.com');

      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, url);
        throw ClientException('test', url);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get(Uri.parse('https://example.com'));
        fail('Method did not throw');
      } on ClientException catch (e) {
        expect(e.message, 'test');
        expect(e.uri, url);
      }

      expect(mockHub.captureExceptionCalls.length, 0);
    });

    /// SocketException are only a thing on dart:io platforms.
    /// otherwise this is equal to the test above
    test('no captureException for SocketException', () async {
      final url = Uri.parse('https://example.com');

      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, url);
        throw SocketException('test');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get(Uri.parse('https://example.com'));
        fail('Method did not throw');
      } on SocketException catch (e) {
        expect(e.message, 'test');
      }

      expect(mockHub.captureExceptionCalls.length, 0);
    });

    test('breadcrumb gets added when an exception gets thrown', () async {
      final url = Uri.parse('https://example.com');

      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, url);
        throw Exception('foo bar');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get(Uri.parse('https://example.com'));
        fail('Method did not throw');
      } on Exception catch (_) {}

      expect(mockHub.addBreadcrumbCalls.length, 1);

      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.level, SentryLevel.error);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('close does get called for user defined client', () async {
      final mockHub = MockHub();

      final mockClient = CloseableMockClient();

      final client = SentryHttpClient(client: mockClient, hub: mockHub);
      client.close();

      expect(mockHub.addBreadcrumbCalls.length, 0);
      expect(mockHub.captureExceptionCalls.length, 0);
      verify(mockClient.close());
    });

    test('Breadcrumb has correct duration', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, Uri.parse('https://example.com'));
        await Future.delayed(Duration(seconds: 1));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get(Uri.parse('https://example.com'));
      expect(response.statusCode, 200);

      expect(mockHub.addBreadcrumbCalls.length, 1);
      final breadcrumb = mockHub.addBreadcrumbCalls.first.crumb;

      var durationString = breadcrumb.data!['duration']! as String;
      // we don't check for anything below a second
      expect(durationString.startsWith('0:00:01'), true);
    });
  });
}

class CloseableMockClient extends Mock implements BaseClient {}
