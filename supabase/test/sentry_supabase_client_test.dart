import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:http/http.dart';

import 'mock_client.dart';
import 'mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('Inner Client', () {
    test('send called on send', () async {
      final sut = fixture.getSut(
        breadcrumbs: true,
        tracing: true,
        errors: true,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));

      await sut.send(request);

      expect(fixture.mockClient.sendCalls.length, 1);
      expect(fixture.mockClient.sendCalls.first, request);
    });

    test('close called on close', () async {
      final sut = fixture.getSut(
        breadcrumbs: true,
        tracing: true,
        errors: true,
      );

      sut.close();

      expect(fixture.mockClient.closeCalls.length, 1);
    });
  });

  group('Inner Sentry Supabase Clients', () {
    test('breadcrumb client', () async {
      final sut = fixture.getSut(
        breadcrumbs: true,
        tracing: false,
        errors: false,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
    });

    test('tracing client', () async {
      final sut = fixture.getSut(
        breadcrumbs: false,
        tracing: true,
        errors: false,
      );

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.startTransactionCalls.length, 1);
    });

    test('error client', () async {
      final sut = fixture.getSut(
        breadcrumbs: false,
        tracing: false,
        errors: true,
      );

      fixture.mockClient.statusCode = 404;

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.captureEventCalls.length, 1);
    });

    test('all clients', () async {
      final sut = fixture.getSut(
        breadcrumbs: true,
        tracing: true,
        errors: true,
      );

      fixture.mockClient.statusCode = 404;

      final request = Request('GET', Uri.parse('https://example.com/123'));
      await sut.send(request);

      expect(fixture.mockHub.addBreadcrumbCalls.length, 1);
      expect(fixture.mockHub.startTransactionCalls.length, 1);
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
    required bool breadcrumbs,
    required bool tracing,
    required bool errors,
  }) {
    return SentrySupabaseClient(
      breadcrumbs: breadcrumbs,
      tracing: tracing,
      errors: errors,
      client: mockClient,
      hub: mockHub,
    );
  }
}
