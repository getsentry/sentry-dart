import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'mocks/mock_client.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('Inner Client', () {
    test('send called on send', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));

      await sut.send(request);

      expect(fixture.mockClient.sendCalls.length, 1);
      expect(fixture.mockClient.sendCalls.first, request);
    });

    test('close called on close', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      sut.close();

      expect(fixture.mockClient.closeCalls.length, 1);
    });
  });

  group('Inner Sentry Supabase Clients', () {
    test('breadcrumb client', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: false,
        enableErrors: false,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('tracing client', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: true,
        enableErrors: false,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.getSpanCallCount, 1);
    });

    test('error client', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: false,
        enableTracing: false,
        enableErrors: true,
      );

      fixture.mockClient.statusCode = 404;

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.captureEventCalls.length, 1);
    });

    test('all clients', () async {
      final sut = fixture.getSut(
        enableBreadcrumbs: true,
        enableTracing: true,
        enableErrors: true,
      );

      fixture.mockClient.statusCode = 404;

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      expect(fixture.mockHub.getSpanCallCount, 1);
      expect(fixture.mockHub.captureEventCalls.length, 1);
    });
  });
}

class Fixture {
  final supabaseUrl = 'https://example.com';

  final options = SentryOptions(
    dsn: 'https://example.com/123',
  );
  final mockClient = MockClient();
  late final mockHub = MockHub(options);

  SentrySupabaseClient getSut({
    required bool enableBreadcrumbs,
    required bool enableTracing,
    required bool enableErrors,
  }) {
    return SentrySupabaseClient(
      enableBreadcrumbs: enableBreadcrumbs,
      enableTracing: enableTracing,
      enableErrors: enableErrors,
      client: mockClient,
      hub: mockHub,
    );
  }
}
