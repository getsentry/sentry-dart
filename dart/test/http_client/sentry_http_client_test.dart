import 'dart:io';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/http_client/sentry_http_client.dart';
import 'package:test/test.dart';

import '../mocks/mock_hub.dart';

final requestUri = Uri.parse('https://example.com');

void main() {
  group(SentryHttpClient, () {
    late Fixture fixture;
    setUp(() {
      fixture = Fixture();
    });

    test('GET: happy path', () async {
      fixture.reasonPhrase = 'OK';

      final response = await fixture.client.get(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['reason'], 'OK');
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('GET: happy path for 404', () async {
      fixture.reasonPhrase = 'NOT FOUND';
      fixture.response = 404;

      final response = await fixture.client.get(requestUri);

      expect(response.statusCode, 404);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'GET');
      expect(breadcrumb.data?['status_code'], 404);
      expect(breadcrumb.data?['reason'], 'NOT FOUND');
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('POST: happy path', () async {
      final response = await fixture.client.post(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'POST');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('PUT: happy path', () async {
      final response = await fixture.client.put(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

      expect(breadcrumb.type, 'http');
      expect(breadcrumb.data?['url'], 'https://example.com');
      expect(breadcrumb.data?['method'], 'PUT');
      expect(breadcrumb.data?['status_code'], 200);
      expect(breadcrumb.data?['duration'], isNotNull);
    });

    test('DELETE: happy path', () async {
      final response = await fixture.client.delete(requestUri);
      expect(response.statusCode, 200);

      expect(fixture.hub.addBreadcrumbCalls.length, 1);
      final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;

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
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, requestUri);
        throw ClientException('test', requestUri);
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get(requestUri);
        fail('Method did not throw');
      } on ClientException catch (e) {
        expect(e.message, 'test');
        expect(e.uri, requestUri);
      }

      expect(mockHub.captureExceptionCalls.length, 0);
    });

    /// SocketException are only a thing on dart:io platforms.
    /// otherwise this is equal to the test above
    test('no captureException for SocketException', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, requestUri);
        throw SocketException('test');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get(requestUri);
        fail('Method did not throw');
      } on SocketException catch (e) {
        expect(e.message, 'test');
      }

      expect(mockHub.captureExceptionCalls.length, 0);
    });

    test('breadcrumb gets added when an exception gets thrown', () async {
      final mockHub = MockHub();

      final mockClient = MockClient((request) async {
        expect(request.url, requestUri);
        throw Exception('foo bar');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      try {
        await client.get(requestUri);
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
        expect(request.url, requestUri);
        await Future.delayed(Duration(seconds: 1));
        return Response('', 200, reasonPhrase: 'OK');
      });

      final client = SentryHttpClient(client: mockClient, hub: mockHub);

      final response = await client.get(requestUri);
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

class Fixture {
  Fixture() {
    hub = MockHub();

    final mockClient = MockClient((request) async {
      expect(request.url, requestUri);
      return Response('', response, reasonPhrase: reasonPhrase);
    });

    client = SentryHttpClient(client: mockClient, hub: hub);
  }

  late MockHub hub;
  late SentryHttpClient client;

  int response = 200;
  String? reasonPhrase;
}
